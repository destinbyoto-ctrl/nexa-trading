// NEXA — Modèles de données du moteur.
import 'dart:convert';

class PairScan {
  final String symbol;
  final double price;
  final double score;      // 0..100
  final double momPct;     // momentum 2h en %
  final bool trendUp;      // EMA9 > EMA21 (15m)
  final double volSpike;   // volume relatif (x)
  final double rsi;        // RSI 14 (15m)
  final double atrPct;     // ATR en % du prix
  final List<String> reasons;

  PairScan({
    required this.symbol,
    required this.price,
    required this.score,
    required this.momPct,
    required this.trendUp,
    required this.volSpike,
    required this.rsi,
    required this.atrPct,
    required this.reasons,
  });

  bool get isHot => score >= 68;
}

class Position {
  final String id;
  final String symbol;
  final double entryPrice;
  final double stake;      // USDT engagés
  final double tpPrice;
  final double slPrice;
  final double targetUsd;  // gain visé en $
  final String mode;       // paper | real
  final String reason;
  final DateTime openedAt;
  double? exitPrice;
  DateTime? closedAt;
  double? pnl;
  double? realQty;         // quantité réelle (mode réel)

  Position({
    required this.id,
    required this.symbol,
    required this.entryPrice,
    required this.stake,
    required this.tpPrice,
    required this.slPrice,
    required this.targetUsd,
    required this.mode,
    required this.reason,
    required this.openedAt,
    this.realQty,
  });

  bool get isOpen => exitPrice == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'entryPrice': entryPrice,
        'stake': stake,
        'tpPrice': tpPrice,
        'slPrice': slPrice,
        'targetUsd': targetUsd,
        'mode': mode,
        'reason': reason,
        'openedAt': openedAt.toIso8601String(),
        'exitPrice': exitPrice,
        'closedAt': closedAt?.toIso8601String(),
        'pnl': pnl,
        'realQty': realQty,
      };

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: j['id'],
        symbol: j['symbol'],
        entryPrice: (j['entryPrice'] as num).toDouble(),
        stake: (j['stake'] as num).toDouble(),
        tpPrice: (j['tpPrice'] as num).toDouble(),
        slPrice: (j['slPrice'] as num).toDouble(),
        targetUsd: (j['targetUsd'] as num).toDouble(),
        mode: j['mode'] ?? 'paper',
        reason: j['reason'] ?? '',
        openedAt: DateTime.parse(j['openedAt']),
        exitPrice: j['exitPrice'] == null ? null : (j['exitPrice'] as num).toDouble(),
        closedAt: j['closedAt'] == null ? null : DateTime.parse(j['closedAt']),
        pnl: j['pnl'] == null ? null : (j['pnl'] as num).toDouble(),
        realQty: j['realQty'] == null ? null : (j['realQty'] as num).toDouble(),
      );

  String encode() => jsonEncode(toJson());
  static Position decode(String s) => Position.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class TradeSettings {
  double targetUsd = 5.0;     // gain visé par entrée
  double minScore = 68;       // seuil de signal
  int maxOpen = 3;            // positions simultanées max
  double maxStakePct = 25;    // % max du capital par position
  int maxHoldMinutes = 360;   // durée max d'une position
  double paperCapital = 1000; // capital mode papier
  bool autoTrade = true;

  Map<String, dynamic> toJson() => {
        'targetUsd': targetUsd,
        'minScore': minScore,
        'maxOpen': maxOpen,
        'maxStakePct': maxStakePct,
        'maxHoldMinutes': maxHoldMinutes,
        'paperCapital': paperCapital,
        'autoTrade': autoTrade,
      };

  factory TradeSettings.fromJson(Map<String, dynamic> j) {
    final s = TradeSettings();
    s.targetUsd = (j['targetUsd'] as num?)?.toDouble() ?? s.targetUsd;
    s.minScore = (j['minScore'] as num?)?.toDouble() ?? s.minScore;
    s.maxOpen = (j['maxOpen'] as num?)?.toInt() ?? s.maxOpen;
    s.maxStakePct = (j['maxStakePct'] as num?)?.toDouble() ?? s.maxStakePct;
    s.maxHoldMinutes = (j['maxHoldMinutes'] as num?)?.toInt() ?? s.maxHoldMinutes;
    s.paperCapital = (j['paperCapital'] as num?)?.toDouble() ?? s.paperCapital;
    s.autoTrade = j['autoTrade'] as bool? ?? s.autoTrade;
    return s;
  }
}
