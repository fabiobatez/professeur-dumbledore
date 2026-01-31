import 'package:flutter/material.dart';

/// AnimatedGradientText
/// Texte avec shimmer/lueur animée via ShaderMask.
class AnimatedGradientText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const AnimatedGradientText(this.text, {super.key, this.style});

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _t = CurvedAnimation(parent: _ctl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final gradient = LinearGradient(
          colors: const [
            Color(0xFFB2EBF2),
            Color(0xFF26C6DA),
            Color(0xFF80DEEA),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1 + 2 * _t.value, -0.2),
          end: const Alignment(1, 0.2),
        );
        return ShaderMask(
          shaderCallback: (rect) => gradient.createShader(rect),
          child: Text(
            widget.text,
            style: (widget.style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
              color: Colors.white,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}