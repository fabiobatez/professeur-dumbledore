import 'dart:math' as math;
import 'package:flutter/material.dart';

/// MagicBackground
/// Arrière-plan animé discret: orbes lumineux, gradient mouvant, étincelles.
class MagicBackground extends StatefulWidget {
  final double intensity; // 0.0..1.0
  const MagicBackground({super.key, this.intensity = 0.8});

  @override
  State<MagicBackground> createState() => _MagicBackgroundState();
}

class _MagicBackgroundState extends State<MagicBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
    _t = CurvedAnimation(parent: _ctl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          return CustomPaint(
            painter: _MagicPainter(t: _t.value, intensity: widget.intensity),
          );
        },
      ),
    );
  }
}

class _MagicPainter extends CustomPainter {
  final double t;
  final double intensity;
  _MagicPainter({required this.t, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = Offset(size.width / 2, size.height / 2);

    // Gradient mouvant
    final g = LinearGradient(
      colors: [
        const Color(0xFF0A0B10),
        const Color(0xFF101428),
        const Color(0xFF0B2236),
      ],
      stops: const [0.0, 0.55, 1.0],
      begin: Alignment(-0.8 + 0.4 * math.sin(t * 2), -0.6),
      end: Alignment(0.8, 0.6 + 0.3 * math.cos(t * 2)),
    );
    final bg = Paint()..shader = g.createShader(rect);
    canvas.drawRect(rect, bg);

    // Orbes lumineux (3)
    final orbPaint = Paint()
      ..color = const Color(0xFF93E9F9).withOpacity(0.08 + 0.12 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    for (var i = 0; i < 3; i++) {
      final phase = t * (1.0 + i * 0.2);
      final r = math.min(size.width, size.height) * (0.18 + 0.06 * i);
      final x = c.dx + math.sin(phase * 2.1 + i) * (size.width * (0.25 + 0.08 * i));
      final y = c.dy + math.cos(phase * 1.7 + i * 0.7) * (size.height * (0.18 + 0.06 * i));
      canvas.drawCircle(Offset(x, y), r, orbPaint);
    }

    // Étincelles: petites particules qui scintillent
    final spark = Paint()
      ..color = const Color(0xFFB2EBF2).withOpacity(0.8 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final count = 90;
    final rnd = math.Random(42); // stable layout
    for (var i = 0; i < count; i++) {
      final px = (rnd.nextDouble() * size.width);
      final py = (rnd.nextDouble() * size.height);
      final tw = 1 + 1.8 * (0.5 + 0.5 * math.sin(t * 6 + i));
      // drift subtil
      final dx = 6 * math.sin(t * 1.2 + i);
      final dy = 4 * math.cos(t * 0.9 + i * 1.3);
      canvas.drawCircle(Offset(px + dx, py + dy), tw, spark);
    }

    // Bordure magique (couronne légère)
    final ring = Paint()
      ..color = const Color(0xFF26C6DA).withOpacity(0.10 + 0.05 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rr = math.min(size.width, size.height) * (0.49 + 0.01 * math.sin(t * 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(8), Radius.circular(12 + 4 * math.sin(t * 3))),
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _MagicPainter old) => old.t != t || old.intensity != intensity;
}