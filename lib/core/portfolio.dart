// NEXA — Portefeuille : positions, TP/SL ciblés en $, journal, persistance.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Portfolio {
  List<Position> open = [];
  List<Position> journal = [];
  double capital = 1000; // capital papier
  double realizedPnl = 0;

  bool hasOpenFor(String symbol) => open.any((p) => p.symbol == symbol);

  /// Ouvre une position calibrée pour viser settings.targetUsd de gain.
  /// TP = 1,6×ATR (borné 1,2..4,5%), stake = cible / TP%, SL = TP/2.
  Position? openPosition(PairScan scan, TradeSettings s, {required bool real, required double price}) {
    if (open.length >= s.maxOpen) return null;
    if (hasOpenFor(scan.symbol)) return null;

    final tpPct = (scan.atrPct * 1.6).clamp(1.2, 4.5);
    var stake = s.targetUsd / (tpPct / 100);
    final cap = capital * s.maxStakePct / 100;
    if (stake > cap) stake = cap;
    if (stake > capital) stake = capital;
    if (stake < 10 || capital < 20) return null; // garde-fou

    final tpPrice = price * (1 + tpPct / 100);
    final slPrice = price * (1 - tpPct / 200);
    final effectiveTarget = stake * tpPct / 100;

    final pos = Position(
      id: '${DateTime.now().millisecondsSinceEpoch}_${scan.symbol}',
      symbol: scan.symbol,
      entryPrice: price,
      stake: stake,
      tpPrice: tpPrice,
      slPrice: slPrice,
      targetUsd: effectiveTarget,
      mode: real ? 'real' : 'paper',
      reason: scan.reasons.join(' · '),
      openedAt: DateTime.now(),
    );
    if (!real) capital -= stake;
    open.add(pos);
    return pos;
  }

  /// Vérifie TP/SL/durée max sur les positions ouvertes.
  /// Retourne les positions à clôturer en réel (mode 'real').
  List<Position> checkExits(Map<String, double> prices, TradeSettings s) {
    final now = DateTime.now();
    final toClose = <Position>[];
    for (final p in open) {
      final px = prices[p.symbol] ?? p.entryPrice;
      final expired = now.difference(p.openedAt).inMinutes >= s.maxHoldMinutes;
      if (px >= p.tpPrice) {
        toClose.add(p);
      } else if (px <= p.slPrice) {
        toClose.add(p);
      } else if (expired) {
        toClose.add(p);
      }
    }
    return toClose;
  }

  /// Clôture une position (papier ou réel déjà exécuté).
  void close(Position p, double exitPrice) {
    final fees = p.stake * 0.002; // 0,1% par côté
    final pnl = p.stake * (exitPrice / p.entryPrice - 1) - fees;
    p.exitPrice = exitPrice;
    p.closedAt = DateTime.now();
    p.pnl = pnl;
    if (p.mode == 'paper') capital += p.stake + pnl;
    realizedPnl += pnl;
    open.removeWhere((x) => x.id == p.id);
    journal.insert(0, p);
    if (journal.length > 200) journal.removeLast();
  }

  int get trades => journal.length;
  int get wins => journal.where((p) => (p.pnl ?? 0) > 0).length;
  double get winrate => trades == 0 ? 0 : wins / trades * 100;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    capital = sp.getDouble('nx_capital') ?? capital;
    realizedPnl = sp.getDouble('nx_realized') ?? 0;
    final j = sp.getString('nx_journal');
    if (j != null) {
      try {
        journal = (jsonDecode(j) as List)
            .map((e) => Position.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final o = sp.getString('nx_open');
    if (o != null) {
      try {
        open = (jsonDecode(o) as List)
            .map((e) => Position.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('nx_capital', capital);
    await sp.setDouble('nx_realized', realizedPnl);
    await sp.setString('nx_journal', jsonEncode(journal.map((p) => p.toJson()).toList()));
    await sp.setString('nx_open', jsonEncode(open.map((p) => p.toJson()).toList()));
  }
}
