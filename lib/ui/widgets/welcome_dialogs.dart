import 'dart:async';
import 'package:flutter/material.dart';
import '/services/backend/backend_service.dart';

class WelcomeDialogs {
  static bool _shown = false;

  static void showIfNeeded(BuildContext context) {
    if (_shown) return;
    if (BackendService.instance.isReady) return;
    _shown = true;
    _showStep1(context);
  }

  static void _showStep1(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _WelcomeStep(
        icon: Icons.downloading_rounded,
        title: 'Preparando Velqi',
        desc: 'Descargando herramientas de\nextracción de audio...',
        onNext: () {
          Navigator.of(ctx).pop();
          _showStep2(context);
        },
      ),
    );
  }

  static void _showStep2(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _WelcomeStep(
        icon: Icons.analytics_outlined,
        title: 'Configurando yt-dlp',
        desc: 'Motor de búsqueda y descarga\nde YouTube Music',
        onNext: () {
          Navigator.of(ctx).pop();
          _showStep3(context);
        },
      ),
    );
  }

  static void _showStep3(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _WelcomeStep(
        icon: Icons.speed_rounded,
        title: 'Casi listo',
        desc: 'Las próximas veces cargará\nmucho más rápido por caché',
        showProgress: true,
        onNext: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _WelcomeStep extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onNext;
  final bool showProgress;

  const _WelcomeStep({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onNext,
    this.showProgress = false,
  });

  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _waitAndClose();
  }

  void _waitAndClose() async {
    if (widget.showProgress) {
      while (mounted && !BackendService.instance.isReady) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      if (mounted) {
        setState(() => _loading = false);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) widget.onNext();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, size: 30, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_loading && widget.showProgress)
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                )
              else if (_loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                )
              else
                Text(
                  '¡Listo!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
