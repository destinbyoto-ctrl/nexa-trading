// NEXA — Chambre du Scanner : radar animé + classement des paires.
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class ScanRoom extends StatefulWidget {
  const ScanRoom({super.key});

  @override
  State<ScanRoom> createState() => _ScanRoomState();
}

class _ScanRoomState extends State<ScanRoom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
    if (!appState.scanning) appState.scanNow();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appState.removeListener(_onChange);
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = appState;
    final top = st.scans.take(10).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Chambre du Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => st.scanNow(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          RadarPanel(controller: _radar, scans: top, scanning: st.scanning),
          const SizedBox(height: 6),
          Center(
            child: Text(
              st.scanning
                  ? 'Balayage en cours…'
                  : 'Dernier scan : ${st.lastScanAt?.hour.toString().padLeft(2, "0")}:${st.lastScanAt?.minute.toString().padLeft(2, "0")} · seuil ${st.settings.minScore.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
            ),
          ),
          const SizedBox(height: 14),
          for (final s in top) _ScanTile(scan: s),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
            ),
        ],
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final PairScan scan;
  const _ScanTile({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        glowColor: scan.isHot
            ? const Color(0x3316D67E)
            : const Color(0x2200E5FF),
        onTap: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(scan.symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                Text(scan.price.toStringAsFixed(4),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
                const Spacer(),
                if (scan.isHot) const Chip(text: 'SETUP', color: Color(0xFF16D67E)),
                const SizedBox(width: 6),
                Text(scan.score.toStringAsFixed(0),
                    style: TextStyle(
                        color: scan.isHot
                            ? const Color(0xFF16D67E)
                            : const Color(0xFF00E5FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            ScoreBar(score: scan.score),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final r in scan.reasons)
                  Chip(text: r, color: const Color(0xFF7C5CFF)),
                if (scan.reasons.isEmpty)
                  Chip(text: 'en attente de signal', color: Color(0x80FFFFFF)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau radar : balayage rotatif + blips des meilleures paires.
class RadarPanel extends StatelessWidget {
  final AnimationController controller;
  final List<PairScan> scans;
  final bool scanning;

  const RadarPanel(
      {super.key,
      required this.controller,
      required this.scans,
      required this.scanning});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(
              progress: controller.value, scans: scans, scanning: scanning),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final List<PairScan> scans;
  final bool scanning;

  _RadarPainter(
      {required this.progress, required this.scans, required this.scanning});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2 - 14;

    // Anneaux.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.18);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 3, ringPaint);
    }
    // Croix.
    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.10);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), linePaint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), linePaint);

    // Secteur balayé (dégradé conique fait main via arcs superposés).
    final sweep = 0.9; // radians
    final start = progress * 2 * 3.14159265;
    for (var i = 0; i < 12; i++) {
      final a = start - sweep * i / 12;
      final alpha = (0.20 * (1 - i / 12)) * (scanning ? 1.4 : 1.0);
      final sector = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF00E5FF)
            .withValues(alpha: alpha.clamp(0.0, 0.28));
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          a - 0.02, 0.06, true, sector);
    }

    // Ligne de balayage.
    final lineEnd = Offset(
        cx + r * (start.cos()), cy + r * (start.sin()));
    final sweepLine = Paint()
      ..strokeWidth = 2
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85);
    canvas.drawLine(Offset(cx, cy), lineEnd, sweepLine);

    // Centre.
    canvas.drawCircle(Offset(cx, cy), 4,
        Paint()..color = const Color(0xFF00E5FF));

    // Blips : les 5 meilleures paires, position par score.
    for (var i = 0; i < scans.length && i < 5; i++) {
      final s = scans[i];
      final angle = (i * 2.399963) % (2 * 3.14159265); // nombre d'or
      final dist = r * (1.05 - (s.score / 100).clamp(0.0, 1.0) * 0.75);
      final px = cx + dist * angle.cos();
      final py = cy + dist * angle.sin();
      // Pulsation décalée par index.
      final pulse = 0.5 + 0.5 * ((progress * 4 + i * 0.23) % 1.0);
      final color =
          s.isHot ? const Color(0xFF16D67E) : const Color(0xFF7C5CFF);
      final glow = Paint()
        ..color = color.withValues(alpha: 0.25 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(px, py), 5 + 3 * pulse, glow);
      canvas.drawCircle(
          Offset(px, py), 3, Paint()..color = color.withValues(alpha: 0.9));
      // Étiquette.
      final tp = TextPainter(
          text: TextSpan(
              text: s.symbol.replaceAll('USDT', ''),
              style: const TextStyle(
                  color: Colors.white, fontSize: 9)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py - 16));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
}
