import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// CMP-35: what the assistant is doing (SPEC-ASSIST-001 REQ-002, REQ-013).
enum KolbiOrbState { idle, listening, processing, responding }

/// The Iridescent AI Orb (06 §3.1). It draws a state value only — no microphone, no speech — and is
/// decorative: the screen states the same thing in words.
///
/// Idle stands still; listening breathes, processing turns its light, responding ripples. One
/// [AnimationController] drives the moving states, and none exists while reduced motion is on.
class KolbiOrb extends StatefulWidget {
  const KolbiOrb({super.key, required this.state, this.size = 160});

  final KolbiOrbState state;
  final double size;

  @override
  State<KolbiOrb> createState() => _KolbiOrbState();
}

class _KolbiOrbState extends State<KolbiOrb> with TickerProviderStateMixin {
  AnimationController? _motion;

  static const _periods = {
    KolbiOrbState.listening: Duration(milliseconds: 1600),
    KolbiOrbState.processing: Duration(milliseconds: 2400),
    KolbiOrbState.responding: Duration(milliseconds: 1200),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KolbiOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final period = reduce ? null : _periods[widget.state];
    if (period == null) {
      _motion?.dispose();
      _motion = null;
      return;
    }
    final motion = _motion ??= AnimationController(vsync: this);
    motion
      ..duration = period
      ..repeat();
  }

  @override
  void dispose() {
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: motion == null
            ? const _Sphere(phase: 0, scaleX: 1, scaleY: 1)
            : AnimatedBuilder(
                animation: motion,
                builder: (context, _) {
                  final t = motion.value * 2 * math.pi;
                  return switch (widget.state) {
                    KolbiOrbState.listening => _Sphere(
                      phase: 0,
                      scaleX: 0.95 + 0.05 * math.sin(t),
                      scaleY: 0.95 + 0.05 * math.sin(t),
                    ),
                    KolbiOrbState.processing => _Sphere(
                      phase: t,
                      scaleX: 1,
                      scaleY: 1,
                    ),
                    _ => _Sphere(
                      phase: t / 2,
                      scaleX: 0.97 + 0.03 * math.sin(t),
                      scaleY: 0.97 + 0.03 * math.cos(t),
                    ),
                  };
                },
              ),
      ),
    );
  }
}

/// The radial gradient of 06 §3.1 (white → #E4E2FF → #A6ACFF → #635BFF → #2E2A78); [phase] moves its light
/// around the sphere.
class _Sphere extends StatelessWidget {
  const _Sphere({
    required this.phase,
    required this.scaleX,
    required this.scaleY,
  });

  final double phase;
  final double scaleX;
  final double scaleY;

  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFE4E2FF),
    Color(0xFFA6ACFF),
    Color(0xFF635BFF),
    Color(0xFF2E2A78),
  ];

  @override
  Widget build(BuildContext context) {
    final light = Alignment(
      -0.35 * math.cos(phase) + 0.35 * math.sin(phase),
      -0.4 * math.cos(phase) - 0.2 * math.sin(phase),
    );
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: light,
            radius: 0.95,
            colors: _colors,
            stops: const [0, 0.18, 0.42, 0.72, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66635BFF),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
