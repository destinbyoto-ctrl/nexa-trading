// NEXA — Chambre des Réglages : objectifs, risques, clés API réelles.
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import 'widgets.dart';

class SettingsRoom extends StatefulWidget {
  const SettingsRoom({super.key});

  @override
  State<SettingsRoom> createState() => _SettingsRoomState();
}

class _SettingsRoomState extends State<SettingsRoom> {
  final _keyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  String _keyMsg = '';

  @override
  void initState() {
    super.initState();
    final st = appState;
    _keyCtrl.text = st.apiKey ?? '';
    _secretCtrl.text = st.apiSecret ?? '';
    appState.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appState.removeListener(_onChange);
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = appState;
    final s = st.settings;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Chambre des Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GlowCard(
            glowColor: const Color(0x2200E5FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Objectif du moteur',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                Text(
                    'Chaque position est calibrée pour viser +${s.targetUsd.toStringAsFixed(2)} \$ de gain (TP basé sur la volatilité, SL à moitié du TP, 0,2% de frais inclus). Aucun gain n\'est garanti : le SL protège le capital.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11)),
                const SizedBox(height: 12),
                _Slider(
                  label: 'Gain visé par entrée',
                  value: s.targetUsd,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  suffix: ' \$',
                  onChanged: (v) => setState(() => s.targetUsd = v),
                  onEnd: (_) => st.saveSettings(),
                ),
                _Slider(
                  label: 'Score minimum (seuil IA)',
                  value: s.minScore,
                  min: 50,
                  max: 95,
                  divisions: 45,
                  suffix: '%',
                  onChanged: (v) => setState(() => s.minScore = v),
                  onEnd: (_) => st.saveSettings(),
                ),
                _Slider(
                  label: 'Positions simultanées max',
                  value: s.maxOpen.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  suffix: '',
                  onChanged: (v) => setState(() => s.maxOpen = v.round()),
                  onEnd: (_) => st.saveSettings(),
                ),
                _Slider(
                  label: 'Mise max par position',
                  value: s.maxStakePct,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  suffix: ' % capital',
                  onChanged: (v) => setState(() => s.maxStakePct = v),
                  onEnd: (_) => st.saveSettings(),
                ),
                _Slider(
                  label: 'Durée max d\'une position',
                  value: s.maxHoldMinutes.toDouble(),
                  min: 30,
                  max: 1440,
                  divisions: 47,
                  suffix: ' min',
                  onChanged: (v) =>
                      setState(() => s.maxHoldMinutes = v.round()),
                  onEnd: (_) => st.saveSettings(),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF00E5FF),
                  title: const Text('Trading autonome',
                      style: TextStyle(fontSize: 13)),
                  subtitle: Text(
                      'L\'IA entre seule sur les setups au-dessus du seuil.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11)),
                  value: s.autoTrade,
                  onChanged: (v) {
                    setState(() => s.autoTrade = v);
                    st.saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlowCard(
            glowColor: const Color(0x227C5CFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key, color: Color(0xFF7C5CFF), size: 16),
                    SizedBox(width: 8),
                    Text('Compte réel Binance (optionnel)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Clés stockées uniquement sur cet appareil (stockage sécurisé). Sans clés, tout fonctionne en mode papier.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11)),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: _input('Clé API'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _secretCtrl,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: _input('Secret API'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await st.setKeys(_keyCtrl.text.trim(),
                              _secretCtrl.text.trim());
                          setState(() =>
                              _keyMsg = 'Clés enregistrées sur l\'appareil.');
                          try {
                            final b = await st.testKeys();
                            setState(() =>
                                _keyMsg = 'Connexion OK · $b USDT');
                          } catch (e) {
                            setState(() => _keyMsg = 'Erreur : $e');
                          }
                        },
                        child: const Text('Enregistrer & tester',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                if (_keyMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_keyMsg,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11)),
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFFFF4D6D),
                  title: const Text('Mode RÉEL',
                      style: TextStyle(fontSize: 13, color: Color(0xFFFF8A9A))),
                  subtitle: Text(
                      st.realMode
                          ? '⚠️ Les ordres partent sur ton compte Binance.'
                          : 'Ordres réels désactivés (papier).',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11)),
                  value: st.realMode,
                  onChanged: (v) async {
                    if (v && (st.apiKey == null || st.apiKey!.isEmpty)) {
                      setState(() =>
                          _keyMsg = 'Enregistre tes clés avant d\'activer le réel.');
                      return;
                    }
                    await st.toggleRealMode(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'NEXA v1.0 · moteur IA multipaires · Binance spot\nLe trading comporte un risque de perte en capital.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _input(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF7C5CFF))),
    );

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(
                  '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}$suffix',
                  style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ),
        SliderTheme(
          data: const SliderThemeData(
              trackHeight: 3, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFF00E5FF),
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ),
      ],
    );
  }
}
