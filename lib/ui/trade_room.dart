// NEXA — Chambre des Positions : ouvertes en direct + capital.
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import 'widgets.dart';

class TradeRoom extends StatefulWidget {
  const TradeRoom({super.key});

  @override
  State<TradeRoom> createState() => _TradeRoomState();
}

class _TradeRoomState extends State<TradeRoom> {
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
    final st = appState;
    final open = st.portfolio.open;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Chambre des Positions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GlowCard(
            glowColor: const Color(0x2200E5FF),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Color(0xFF00E5FF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${st.portfolio.capital.toStringAsFixed(2)} USDT',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(st.realMode ? 'compte réel' : 'capital papier',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11)),
                    ],
                  ),
                ),
                Chip(
                    text:
                        'P&L ${st.portfolio.realizedPnl >= 0 ? "+" : ""}${st.portfolio.realizedPnl.toStringAsFixed(2)} \$',
                    color: st.portfolio.realizedPnl >= 0
                        ? const Color(0xFF16D67E)
                        : const Color(0xFFFF4D6D)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (open.isEmpty)
            const GlowCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text('Aucune position ouverte.\nLe scanner attend un setup…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          for (final p in open) _OpenTile(pos: p),
        ],
      ),
    );
  }
}

class _OpenTile extends StatelessWidget {
  final Position pos;
  const _OpenTile({required this.pos});

  @override
  Widget build(BuildContext context) {
    final st = appState;
    final px = st.prices[pos.symbol] ?? pos.entryPrice;
    final pnl = pos.stake * (px / pos.entryPrice - 1);
    final progress =
        ((pnl / (pos.targetUsd > 0 ? pos.targetUsd : 1)) + 0.0).clamp(0.0, 1.0);
    final up = pnl >= 0;
    final held = DateTime.now().difference(pos.openedAt).inMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        glowColor: up ? const Color(0x3316D67E) : const Color(0x33FF4D6D),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(pos.symbol,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 8),
                Chip(
                    text: pos.mode == 'real' ? 'RÉEL' : 'PAPIER',
                    color: pos.mode == 'real'
                        ? const Color(0xFFFF4D6D)
                        : const Color(0xFF00E5FF)),
                const Spacer(),
                Text(
                    '${up ? "+" : ""}${pnl.toStringAsFixed(2)} \$',
                    style: TextStyle(
                        color: up ? const Color(0xFF16D67E) : const Color(0xFFFF4D6D),
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Entrée ${pos.entryPrice.toStringAsFixed(4)} · live ${px.toStringAsFixed(4)} · ${held} min',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
            const SizedBox(height: 6),
            Text(
                'Cible +${pos.targetUsd.toStringAsFixed(2)} \$ (TP ${pos.tpPrice.toStringAsFixed(4)}) · protection (SL ${pos.slPrice.toStringAsFixed(4)})',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
            const SizedBox(height: 10),
            // Progression vers l'objectif $.
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: progress, end: progress),
                duration: const Duration(milliseconds: 500),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(up
                      ? const Color(0xFF16D67E)
                      : const Color(0xFFFF4D6D)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text(pos.reason,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10))),
                TextButton(
                  onPressed: () => st.closeManually(pos),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text('Clôturer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
