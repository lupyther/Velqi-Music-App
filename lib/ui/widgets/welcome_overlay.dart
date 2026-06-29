import 'dart:async';
import 'package:flutter/material.dart';
import '/services/backend/backend_service.dart';

class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key});

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with TickerProviderStateMixin {
  bool _visible = true;
  int _currentStep = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slide;

  final _steps = const [
    _StepData(
      icon: Icons.downloading_rounded,
      title: 'Preparando Velqi',
      desc: 'Descargando herramientas de extracción de audio...',
    ),
    _StepData(
      icon: Icons.analytics_outlined,
      title: 'Configurando yt-dlp',
      desc: 'Motor de búsqueda y descarga de YouTube Music',
    ),
    _StepData(
      icon: Icons.speed_rounded,
      title: 'Casi listo',
      desc: 'Las próximas veces cargará mucho más rápido por caché',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();
    _cycleSteps();
    _pollBackend();
  }

  void _cycleSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() => _currentStep = i);
      _slideCtrl.reset();
      _slideCtrl.forward();
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _pollBackend() async {
    while (mounted) {
      if (BackendService.instance.isReady) {
        _dismiss();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _dismiss() {
    if (!mounted) return;
    _fadeCtrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final step = _steps[_currentStep];

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 36,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Velqi',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SlideTransition(
                    position: _slide,
                    child: Column(
                      children: [
                        Icon(
                          step.icon,
                          size: 40,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.desc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.5),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _steps.length,
                        minHeight: 3,
                        backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String desc;
  const _StepData({required this.icon, required this.title, required this.desc});
}
