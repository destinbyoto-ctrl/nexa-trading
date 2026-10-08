// NEXA — Client API Binance (REST + signatures HMAC pour le mode réel).
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BinanceApi {
  static const String base = 'https://api.binance.com';

  /// Top paires USDT par volume 24h (exclut tokens à levier).
  static Future<List<String>> topUsdtSymbols({int limit = 24}) async {
    final r = await http.get(Uri.parse('$base/api/v3/ticker/24hr'));
    if (r.statusCode != 200) throw Exception('ticker24h: ${r.statusCode}');
    final list = jsonDecode(r.body) as List;
    final rows = list.whereType<Map<String, dynamic>>().where((m) {
      final s = m['symbol'] as String?;
      final v = m['quoteVolume'];
      return s != null &&
          v is num &&
          s.endsWith('USDT') &&
          !s.endsWith('UPUSDT') &&
          !s.endsWith('DOWNUSDT') &&
          !s.endsWith('BULLUSDT') &&
          !s.endsWith('BEARUSDT') &&
          s.length > 5;
    }).toList();
    rows.sort((a, b) => (b['quoteVolume'] as num).compareTo(a['quoteVolume'] as num));
    return rows.take(limit).map((m) => m['symbol'] as String).toList();
  }

  /// Klines brutes : [openTime, open, high, low, close, volume, ...]
  static Future<List<List<dynamic>>> klines(String symbol, String interval, {int limit = 120}) async {
    final r = await http.get(Uri.parse(
        '$base/api/v3/klines?symbol=$symbol&interval=$interval&limit=$limit'));
    if (r.statusCode != 200) throw Exception('klines $symbol: ${r.statusCode}');
    return (jsonDecode(r.body) as List).whereType<List<dynamic>>().toList();
  }

  /// Requête signée (mode réel). Retourne le JSON de réponse.
  static Future<Map<String, dynamic>> signed(
    String path,
    Map<String, String> params,
    String apiKey,
    String secret, {
    String method = 'POST',
  }) async {
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
    params['recvWindow'] = '10000';
    final query =
        params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final sig = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(query)).toString();
    final uri = Uri.parse('$base$path?$query&signature=$sig');
    final r = method == 'POST'
        ? await http.post(uri, headers: {'X-MBX-APIKEY': apiKey})
        : await http.get(uri, headers: {'X-MBX-APIKEY': apiKey});
    final body = jsonDecode(r.body);
    if (r.statusCode != 200) {
      throw Exception('Binance ${r.statusCode}: ${body is Map ? body['msg'] : body}');
    }
    return body as Map<String, dynamic>;
  }

  /// Solde du compte (test des clés API).
  static Future<double> usdtBalance(String apiKey, String secret) async {
    final j = await signed('/api/v3/account', {}, apiKey, secret, method: 'GET');
    final balances = (j['balances'] as List).whereType<Map<String, dynamic>>();
    final usdt = balances.firstWhere((b) => b['asset'] == 'USDT',
        orElse: () => {'free': 0});
    return double.tryParse('${usdt['free']}') ?? 0;
  }
}
