// NEXA — Chambre du Journal : historique et statistiques.
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class JournalRoom extends StatefulWidget {
  const JournalRoom({super.key});

  @override
  State<JournalRoom> createState() => _JournalRoomState();
}

class _JournalRoomState extends State<JournalRoom> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = appState.portfolio;
    final journal = p.journal;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Chambre du Journal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      label: 'Trades',
                      value: '${p.trades}',
                      color: const Color(0xFF00E5FF))),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat(
                      label: 'Réussite',
                      value: '${p.winrate.toStringAsFixed(0)}%',
                      color: const Color(0xFF16D67E))),
              const SizedBox(width: 10),
              Expanded(
                  child: _Stat(
                      label: 'P&L total',
                      value:
                          '${p.realizedPnl >= 0 ? "+" : ""}${p.realizedPnl.toStringAsFixed(2)} \$',
                      color: p.realizedPnl >= 0
                          ? const Color(0xFF16D67E)
                          : const Color(0xFFFF4D6D))),
            ],
          ),
          const SizedBox(height: 16),
          if (journal.isEmpty)
            const GlowCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                    child: Text('Le journal est vide.\nLes sorties apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54))),
              ),
            ),
          for (final t in journal) _JournalTile(t: t),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(14),
      glowColor: color.withValues(alpha: 0.15),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  final Position t;
  const _JournalTile({required this.t});

  @override
  Widget build(BuildContext context) {
    final pnl = t.pnl ?? 0;
    final win = pnl >= 0;
    final d = t.closedAt ?? t.openedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        padding: const EdgeInsets.all(14),
        glowColor: win ? const Color(0x2216D67E) : const Color(0x22FF4D6D),
        child: Row(
          children: [
            Icon(win ? Icons.check_circle : Icons.cancel,
                color: win ? const Color(0xFF16D67E) : const Color(0xFFFF4D6D),
                size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.symbol} · ${t.mode == 'real' ? "RÉEL" : "PAPIER"}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                      '${t.entryPrice.toStringAsFixed(4)} → ${(t.exitPrice ?? 0).toStringAsFixed(4)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${win ? "+" : ""}${pnl.toStringAsFixed(2)} \$',
                    style: TextStyle(
                        color: win
                            ? const Color(0xFF16D67E)
                            : const Color(0xFFFF4D6D),
                        fontWeight: FontWeight.w800)),
                Text(
                    '${d.day}/${d.month} ${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
