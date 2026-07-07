import 'dart:async';
import 'package:flutter/material.dart';
import '/services/backend/backend_service.dart';
import '/ui/home.dart';

/// Velqi animated splash screen.
/// Muestra el logo animado mientras el backend Python (yt-dlp + ytmusicapi)
/// termina de inicializarse. Solo navega al Home cuando el backend reporta
/// status == "initialized" (100%). Así el Home arranca con todo listo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── animation controllers ────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _dotsCtrl; // loading dots loop
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;

  // ── backend state ────────────────────────────────────────────────────────
  static const _maxWait = Duration(seconds: 90);
  static const _pollInterval = Duration(milliseconds: 800);
  String _statusText = 'Iniciando Velqi...';
  double _progressValue = 0.0; // 0.0 → 1.0
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // Logo: scale from 0.6 → 1.0, fade 0 → 1 over 900ms
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn));

    // Subtitle text fade-in with a short delay
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn));

    // Dots animation — repeats indefinitely
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textCtrl.forward();
    });

    _waitForBackend();
  }

  /// Espera al backend real antes de navegar.
  /// Muestra progreso real del backend en la barra inferior.
  void _waitForBackend() async {
    final deadline = DateTime.now().add(_maxWait);
    final backendService = BackendService.instance;

    // Fase inicial visual (logo aparece)
    await Future.delayed(const Duration(milliseconds: 800));

    while (mounted && DateTime.now().isBefore(deadline)) {
      try {
        final status = await backendService.getInitStatus();
        final pct = (status['progress'] as num? ?? 0).toDouble();
        final msg = status['message'] as String? ?? '';
        final initialized = status['status'] == 'initialized';

        if (mounted) {
          setState(() {
            _progressValue = (pct / 100.0).clamp(0.0, 1.0);
            _statusText = _friendlyMessage(msg, pct.toInt());
          });
        }

        if (initialized) {
          // Backend 100% listo — navegar al Home
          if (mounted) {
            setState(() {
              _progressValue = 1.0;
              _statusText = '¡Listo!';
            });
          }
          await Future.delayed(const Duration(milliseconds: 350));
          _goHome();
          return;
        }
      } catch (_) {
        // Backend aún no responde, seguir esperando
        if (mounted) {
          setState(() {
            _statusText = 'Iniciando motor...';
            _progressValue = (_progressValue + 0.01).clamp(0.0, 0.35);
          });
        }
      }

      await Future.delayed(_pollInterval);
    }

    // Timeout — navegar igual (el Home mostrará su estado)
    _goHome();
  }

  String _friendlyMessage(String raw, int pct) {
    if (raw.startsWith('Error')) return 'Reintentando...';
    if (pct <= 0) return 'Iniciando motor de audio...';
    if (pct < 20) return 'Cargando núcleo Python...';
    if (pct < 60) return 'Cargando yt-dlp...';
    if (pct < 100) return 'Cargando ytmusicapi...';
    return '¡Listo!';
  }

  void _goHome() {
    if (_navigating || !mounted) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Home(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── pure black background ────────────────────────────────────
            const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),

            // ── center content ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: _buildLogo(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App name
                  FadeTransition(
                    opacity: _textFade,
                    child: const Column(
                      children: [
                        Text(
                          'Velqi',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Free Music',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB3B3B3),
                            letterSpacing: 4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── bottom progress area ─────────────────────────────────────
            Positioned(
              bottom: 48,
              left: 40,
              right: 40,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    // Status text with animated dots
                    AnimatedBuilder(
                      animation: _dotsCtrl,
                      builder: (_, __) {
                        final dotCount = (_dotsCtrl.value * 4).floor() % 4;
                        final dots = '.' * dotCount + ' ' * (3 - dotCount);
                        return Text(
                          '$_statusText$dots',
                          style: const TextStyle(
                            color: Color(0xFF8A8A8A),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Gradient progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: _progressValue),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        builder: (_, value, __) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 4,
                            backgroundColor: const Color(0xFF1E1E1E),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(48),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30FFFFFF),
            blurRadius: 80,
            spreadRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: Image.asset(
          'assets/velqi_splash.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF0A0A0A),
            child: const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
