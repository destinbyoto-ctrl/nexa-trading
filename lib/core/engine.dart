// NEXA — Moteur de scoring IA multipaires.
// Score 0-100 : momentum multi-TF + tendance EMA + pic de volume + RSI.
import 'models.dart';

class ScanEngine {
  static List<double> ema(List<double> v, int n) {
    if (v.isEmpty) return [];
    final k = 2 / (n + 1);
    final out = <double>[v.first];
    for (var i = 1; i < v.length; i++) {
      out.add(v[i] * k + out.last * (1 - k));
    }
    return out;
  }

  static double rsi(List<double> closes, {int n = 14}) {
    if (closes.length < n + 1) return 50;
    var gains = 0.0, losses = 0.0;
    for (var i = closes.length - n; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      if (d >= 0) {
        gains += d;
      } else {
        losses -= d;
      }
    }
    if (losses == 0) return 100;
    final rs = (gains / n) / (losses / n);
    return 100 - 100 / (1 + rs);
  }

  static double _avg(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  /// ATR% (True Range moyen sur 14 bougies, en % du dernier prix).
  static double atrPct(List<List<dynamic>> k) {
    if (k.length < 16) return 1.5;
    final closes = k.map((r) => double.tryParse('${r[4]}') ?? 0).toList();
    var trSum = 0.0;
    for (var i = k.length - 14; i < k.length; i++) {
      final high = double.tryParse('${k[i][2]}') ?? 0;
      final low = double.tryParse('${k[i][3]}') ?? 0;
      final prevClose = closes[i - 1];
      final tr = (high - low).abs().clamp(0, double.infinity) > 0
          ? (high - low).abs().clamp(0, (high - prevClose).abs() + (low - prevClose).abs() + 0.0000001)
          : 0;
      trSum += (high - low).abs().clamp(0, double.infinity) +
          0; // TR simple si prev manquant
    }
    final atr = trSum / 14;
    final last = closes.last;
    return last > 0 ? (atr / last) * 100 : 1.5;
  }

  /// Analyse une paire et produit un score 0-100.
  /// k15 : klines 15m (>= 30), k1h : klines 1h (>= 30).
  static PairScan scan({
    required String symbol,
    required double price,
    required List<List<dynamic>> k15,
    required List<List<dynamic>> k1h,
  }) {
    final c15 = k15.map((r) => double.tryParse('${r[4]}') ?? 0).toList();
    final v15 = k15.map((r) => double.tryParse('${r[5]}') ?? 0).toList();
    final c1h = k1h.map((r) => double.tryParse('${r[4]}') ?? 0).toList();

    // Momentum 2h (8 bougies 15m).
    final momPct = c15.length >= 9 && c15[c15.length - 9] > 0
        ? (c15.last - c15[c15.length - 9]) / c15[c15.length - 9] * 100
        : 0.0;

    // Tendance : EMA9 > EMA21 sur 15m et 1h, prix au-dessus de l'EMA9 15m.
    final e9 = ema(c15, 9);
    final e21 = ema(c15, 21);
    final e9h = ema(c1h, 9);
    final e21h = ema(c1h, 21);
    final trendUp = e9.isNotEmpty &&
        e21.length >= 2 &&
        e9.last > e21.last &&
        c15.last > e9.last &&
        e9h.length >= 2 &&
        e9h.last > e21h.last;

    // Pic de volume : dernière bougie vs moyenne 20.
    final volAvg = _avg(v15.length > 21 ? v15.sublist(v15.length - 21, v15.length - 1) : v15);
    final volSpike = volAvg > 0 ? v15.last / volAvg : 1.0;

    final rsiV = rsi(c15);

    // Composition du score (long uniquement, spot).
    final momScore = (momPct * 25).clamp(0.0, 40.0);
    final trendScore = trendUp ? 30.0 : 0.0;
    final volScore = ((volSpike - 1) * 20).clamp(0.0, 15.0);
    final rsiScore = rsiV >= 45 && rsiV <= 68 ? 15.0 : (rsiV > 40 && rsiV < 78 ? 8.0 : 0.0);
    final score = momScore + trendScore + volScore + rsiScore;

    final reasons = <String>[];
    if (momPct > 0.2) reasons.add('Momentum ${momPct.toStringAsFixed(1)}%');
    if (trendUp) reasons.add('Tendance haussière EMA');
    if (volSpike > 1.5) reasons.add('Volume ×${volSpike.toStringAsFixed(1)}');
    if (rsiScore >= 15) reasons.add('RSI ${rsiV.toStringAsFixed(0)} sain');

    return PairScan(
      symbol: symbol,
      price: price,
      score: score,
      momPct: momPct,
      trendUp: trendUp,
      volSpike: volSpike,
      rsi: rsiV,
      atrPct: atrPct(k15),
      reasons: reasons,
    );
  }
}
