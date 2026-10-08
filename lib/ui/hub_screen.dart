// NEXA — Le Hub : le hall d'entrée des chambres, avec portes animées.
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import 'widgets.dart';
import 'scan_room.dart';
import 'trade_room.dart';
import 'journal_room.dart';
import 'settings_room.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
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

  void _open(Widget room) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => room, fullscreenDialog: false));
  }

  @override
  Widget build(BuildContext context) {
    final st = appState;
    final pnl = st.portfolio.realizedPnl;
    return Scaffold(
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1030), Color(0xFF060913), Color(0xFF0D0A24)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              Row(
                children: [
                  const PulsingDot(color: Color(0xFF16D67E)),
                  const SizedBox(width: 8),
                  Text(st.wsConnected ? 'MARCHÉ EN DIRECT' : 'RECONNEXION…',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          letterSpacing: 1.5)),
                  const Spacer(),
                  const Icon(Icons.radar, color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 6),
                  const Text('NEXA',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 3)),
                ],
              ),
              const SizedBox(height: 26),
              const Text('Les chambres',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(st.statusLine,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 22),
              _Room(
                icon: Icons.radar,
                title: 'Chambre du Scanner',
                subtitle:
                    '${st.scans.length} paires · top : ${st.scans.isEmpty ? "—" : st.scans.first.symbol}',
                colors: const [Color(0xFF00E5FF), Color(0xFF0092FF)],
                badge: st.scanning ? 'balayage…' : 'prêt',
                onTap: () => _open(const ScanRoom()),
              ),
              const SizedBox(height: 14),
              _Room(
                icon: Icons.trending_up,
                title: 'Chambre des Positions',
                subtitle:
                    '${st.portfolio.open.length} ouverte(s) · cible +${st.settings.targetUsd.toStringAsFixed(0)} \$ / entrée',
                colors: const [Color(0xFF16D67E), Color(0xFF0AA5C9)],
                badge: '${st.portfolio.open.length}',
                onTap: () => _open(const TradeRoom()),
              ),
              const SizedBox(height: 14),
              _Room(
                icon: Icons.book,
                title: 'Chambre du Journal',
                subtitle:
                    '${st.portfolio.trades} trades · ${st.portfolio.winrate.toStringAsFixed(0)}% réussite',
                colors: const [Color(0xFF7C5CFF), Color(0xFFB45CFF)],
                badge: pnl >= 0 ? '+${pnl.toStringAsFixed(2)} \$' : '${pnl.toStringAsFixed(2)} \$',
                onTap: () => _open(const JournalRoom()),
              ),
              const SizedBox(height: 14),
              _Room(
                icon: Icons.tune,
                title: 'Chambre des Réglages',
                subtitle: st.realMode ? 'MODE RÉEL ACTIF' : 'mode papier (démo)',
                colors: st.realMode
                    ? const [Color(0xFFFF4D6D), Color(0xFFFF8A5C)]
                    : const [Color(0xFF3A4A6E), Color(0xFF2A3A5E)],
                badge: st.realMode ? 'RÉEL' : 'PAPIER',
                onTap: () => _open(const SettingsRoom()),
              ),
              const SizedBox(height: 26),
              if (st.lastAction.isNotEmpty)
                GlowCard(
                  glowColor: const Color(0x3316D67E),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF16D67E), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(st.lastAction,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Capital papier : ${st.portfolio.capital.toStringAsFixed(2)} USDT',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Room extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final List<Color> colors;
  final VoidCallback onTap;

  const _Room({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors[0].withValues(alpha: 0.22), colors[1].withValues(alpha: 0.10)]),
            border: Border.all(color: colors[0].withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(color: colors[0].withValues(alpha: 0.25), blurRadius: 24, spreadRadius: -8),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: colors),
                ),
                child: Icon(icon, color: const Color(0xFF060913), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11)),
                  ],
                ),
              ),
              Chip(text: badge, color: colors[0]),
            ],
          ),
        ),
      ),
    );
  }
}
