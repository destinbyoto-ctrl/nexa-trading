// NEXA — Point d'entrée. Thème sombre "chambres" avec ambiance néon.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_state.dart';
import 'ui/hub_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const NexaApp());
}

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060913),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ).copyWith(primary: const Color(0xFF00E5FF)),
        fontFamily: null,
      ),
      home: const BootScreen(),
    );
  }
}

/// Écran de démarrage : lance l'état puis ouvre le hub.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    appState.init();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HubScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutBack,
              builder: (context, v, _) =>
                  Transform.scale(scale: v, child: _Logo()),
            ),
            const SizedBox(height: 24),
            const Text('N E X A',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('Chambres de trading IA',
                style: TextStyle(
                    color: Colors.cyan.withValues(alpha: 0.8), fontSize: 13)),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: const Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [
          Color(0xFF00E5FF),
          Color(0xFF7C5CFF),
        ]),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
              blurRadius: 40),
        ],
      ),
      child: const Icon(Icons.radar, size: 44, color: Color(0xFF060913)),
    );
  }
}
