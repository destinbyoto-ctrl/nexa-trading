// NEXA — État global : scanner multipaires, WebSocket live, exécution.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'binance_api.dart';
import 'engine.dart';
import 'models.dart';
import 'portfolio.dart';

/// Instance unique partagée par toutes les chambres.
final AppState appState = AppState();

class AppState extends ChangeNotifier {
  final Portfolio portfolio = Portfolio();
  final TradeSettings settings = TradeSettings();
  final _storage = const FlutterSecureStorage();

  List<PairScan> scans = [];
  Map<String, double> prices = {};
  List<String> symbols = [];
  bool scanning = false;
  bool wsConnected = false;
  DateTime? lastScanAt;
  String statusLine = 'Initialisation…';
  String lastAction = '';

  bool realMode = false;
  String? apiKey;
  String? apiSecret;
  double realBalance = 0;

  Timer? _scanTimer;
  Timer? _tickTimer;
  WebSocket? _ws;
  Timer? _reconnect;
  final Map<String, DateTime> _cooldown = {};

  bool _disposed = false;

  Future<void> init() async {
    await portfolio.load();
    await _loadSettings();
    await _loadKeys();
    unawaited(start());
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('nx_settings');
    if (s != null) {
      final tmp = TradeSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      settings.targetUsd = tmp.targetUsd;
      settings.minScore = tmp.minScore;
      settings.maxOpen = tmp.maxOpen;
      settings.maxStakePct = tmp.maxStakePct;
      settings.maxHoldMinutes = tmp.maxHoldMinutes;
      settings.paperCapital = tmp.paperCapital;
      settings.autoTrade = tmp.autoTrade;
    }
  }

  Future<void> saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('nx_settings', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> _loadKeys() async {
    apiKey = await _storage.read(key: 'nx_api_key');
    apiSecret = await _storage.read(key: 'nx_api_secret');
    if (apiKey != null && apiSecret != null) {
      realMode = (await _storage.read(key: 'nx_real_mode')) == '1';
    }
  }

  Future<void> setKeys(String key, String secret) async {
    apiKey = key;
    apiSecret = secret;
    await _storage.write(key: 'nx_api_key', value: key);
    await _storage.write(key: 'nx_api_secret', value: secret);
  }

  Future<double> testKeys() async {
    if (apiKey == null || apiSecret == null) throw Exception('Clés absentes');
    realBalance = await BinanceApi.usdtBalance(apiKey!, apiSecret!);
    notifyListeners();
    return realBalance;
  }

  Future<void> toggleRealMode(bool on) async {
    realMode = on;
    await _storage.write(key: 'nx_real_mode', value: on ? '1' : '0');
    notifyListeners();
  }

  Future<void> start() async {
    statusLine = 'Connexion aux marchés…';
    notifyListeners();
    try {
      symbols = await BinanceApi.topUsdtSymbols(limit: 24);
      statusLine = '${symbols.length} paires suivies';
      _connectWs();
      unawaited(scanNow());
      _scanTimer?.cancel();
      _scanTimer =
          Timer.periodic(const Duration(seconds: 30), (_) => unawaited(scanNow()));
      _tickTimer?.cancel();
      _tickTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    } catch (e) {
      statusLine = 'Erreur API : $e';
    }
    notifyListeners();
  }

  void _connectWs() {
    if (symbols.isEmpty) return;
    final streams = symbols.map((s) => '${s.toLowerCase()}@miniTicker').join('/');
    try {
      WebSocket.connect('wss://stream.binance.com:9443/stream?streams=$streams')
          .then((ws) {
        _ws = ws;
        wsConnected = true;
        notifyListeners();
        ws.listen(
          (data) {
            try {
              final j = jsonDecode(data as String) as Map<String, dynamic>;
              final d = j['data'] as Map<String, dynamic>?;
              if (d != null && d['s'] != null && d['c'] != null) {
                prices['${d['s']}'] = double.tryParse('${d['c']}') ?? 0;
              }
            } catch (_) {}
          },
          onDone: _onWsDown,
          onError: (_) => _onWsDown(),
          cancelOnError: true,
        );
      }).catchError((_) => _onWsDown());
    } catch (_) {
      _onWsDown();
    }
  }

  void _onWsDown() {
    wsConnected = false;
    notifyListeners();
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), _connectWs);
  }

  Future<void> scanNow() async {
    if (scanning || symbols.isEmpty) return;
    scanning = true;
    statusLine = 'Balayage du marché…';
    notifyListeners();
    final results = <PairScan>[];
    // Par vagues de 6 pour la vitesse (anti-lenteur).
    for (var i = 0; i < symbols.length; i += 6) {
      if (_disposed) return;
      final batch = symbols.skip(i).take(6).toList();
      final scanned = await Future.wait(batch.map((sym) => _scanOne(sym)));
      results.addAll(scanned.whereType<PairScan>());
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    if (_disposed) return;
    scans = results;
    scanning = false;
    lastScanAt = DateTime.now();
    statusLine = '${scans.length} paires analysées';
    if (settings.autoTrade) _executeSignals();
    notifyListeners();
  }

  Future<PairScan?> _scanOne(String sym) async {
    try {
      final k15 = await BinanceApi.klines(sym, '15m', limit: 60);
      final k1h = await BinanceApi.klines(sym, '1h', limit: 40);
      final price = double.tryParse('${k15.last[4]}') ?? 0;
      if (price <= 0) return null;
      return ScanEngine.scan(symbol: sym, price: price, k15: k15, k1h: k1h);
    } catch (_) {
      return null;
    }
  }

  void _executeSignals() {
    for (final scan in scans) {
      if (scan.score < settings.minScore) break; // liste triée desc
      if (portfolio.open.length >= settings.maxOpen) break;
      final last = _cooldown[scan.symbol];
      if (last != null &&
          DateTime.now().difference(last).inMinutes < 15) {
        continue;
      }
      final px = prices[scan.symbol] ?? scan.price;
      final pos =
          portfolio.openPosition(scan, settings, real: realMode, price: px);
      if (pos != null) {
        _cooldown[scan.symbol] = DateTime.now();
        lastAction =
            '${realMode ? "RÉEL" : "PAPIER"} : entrée ${scan.symbol} @ ${px.toStringAsFixed(4)} → cible +${pos.targetUsd.toStringAsFixed(2)} \$';
        if (realMode) unawaited(_realBuy(pos, px));
      }
    }
    unawaited(portfolio.save());
  }

  Future<void> _realBuy(Position pos, double px) async {
    try {
      final j = await BinanceApi.signed('/api/v3/order', {
        'symbol': pos.symbol,
        'side': 'BUY',
        'type': 'MARKET',
        'quoteOrderQty': pos.stake.toStringAsFixed(2),
      }, apiKey!, apiSecret!);
      pos.realQty = double.tryParse('${j['executedQty']}');
      lastAction = 'Ordre réel exécuté : ${pos.symbol}';
      notifyListeners();
    } catch (e) {
      lastAction = 'Ordre réel échoué : $e';
      portfolio.open.removeWhere((x) => x.id == pos.id);
      notifyListeners();
    }
  }

  Future<void> _realSell(Position pos) async {
    try {
      await BinanceApi.signed('/api/v3/order', {
        'symbol': pos.symbol,
        'side': 'SELL',
        'type': 'MARKET',
        'quantity': (pos.realQty ?? 0).toStringAsFixed(6),
      }, apiKey!, apiSecret!);
    } catch (_) {}
  }

  void _tick() {
    final toClose = portfolio.checkExits(prices, settings);
    for (final p in toClose) {
      final px = prices[p.symbol] ?? p.entryPrice;
      if (p.mode == 'real') unawaited(_realSell(p));
      portfolio.close(p, px);
      final pnl = p.pnl ?? 0;
      lastAction =
          'Sortie ${p.symbol} @ ${px.toStringAsFixed(4)} → ${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(2)} \$';
    }
    if (toClose.isNotEmpty) unawaited(portfolio.save());
    notifyListeners();
  }

  /// Clôture manuelle depuis la chambre des positions.
  Future<void> closeManually(Position p) async {
    final px = prices[p.symbol] ?? p.entryPrice;
    if (p.mode == 'real') await _realSell(p);
    portfolio.close(p, px);
    await portfolio.save();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanTimer?.cancel();
    _tickTimer?.cancel();
    _reconnect?.cancel();
    _ws?.close();
    super.dispose();
  }
}
