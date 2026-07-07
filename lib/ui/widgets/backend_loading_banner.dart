import 'dart:async';
import 'package:flutter/material.dart';
import '/services/backend/backend_service.dart';

class BackendLoadingBanner extends StatefulWidget {
  const BackendLoadingBanner({super.key});

  @override
  State<BackendLoadingBanner> createState() => _BackendLoadingBannerState();
}

class _BackendLoadingBannerState extends State<BackendLoadingBanner>
    with SingleTickerProviderStateMixin {
  late bool _visible;
  late bool _ready;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _ready = BackendService.instance.isReady;
    _visible = !_ready;

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (_visible) {
      _fadeCtrl.forward();
      _pollBackend();
    }
  }

  void _pollBackend() async {
    while (mounted && !_ready) {
      final ok = await BackendService.instance.ensureReady(
          timeout: const Duration(seconds: 2));
      if (ok && mounted) {
        setState(() => _ready = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          _fadeCtrl.reverse().then((_) {
            if (mounted) setState(() => _visible = false);
          });
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fade,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 10,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            bottom: BorderSide(
              color: _ready
                  ? Colors.greenAccent.withOpacity(0.3)
                  : cs.onSurface.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: _ready
                  ? Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.greenAccent)
                  : Image.asset(
                      'assets/velqi_headphones.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _ready ? 'Velqi listo' : 'Inicializando motor de audio...',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(_ready ? 0.7 : 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
