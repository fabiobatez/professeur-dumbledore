import 'dart:math' as math;
import 'package:flutter/material.dart';

class PatronusLoader extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onCompleted;

  const PatronusLoader({
    super.key,
    required this.duration,
    this.onCompleted,
  });

  @override
  State<PatronusLoader> createState() => _PatronusLoaderState();
}

class _PatronusLoaderState extends State<PatronusLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward().then((_) {
      widget.onCompleted?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _LoaderPainter(_controller.value),
            size: const Size(100, 100),
          );
        },
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double progress;
  _LoaderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Outer circle
    paint.color = const Color(0xFFAB47BC).withOpacity(0.3);
    canvas.drawCircle(center, radius, paint);

    // Rotating arc
    paint.color = const Color(0xFF26C6DA);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );

    // Inner sparkles
    final rnd = math.Random(42);
    final sparklePaint = Paint()..color = Colors.white;
    for (int i = 0; i < 5; i++) {
      final angle = rnd.nextDouble() * 2 * math.pi + progress * 10;
      final r = rnd.nextDouble() * radius * 0.8;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2 * (1 - progress), sparklePaint);
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter oldDelegate) => oldDelegate.progress != progress;
}
