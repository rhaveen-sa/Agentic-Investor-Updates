import 'package:flutter/material.dart';

import 'common.dart';

/// Text with a light sweeping across it, used while the agent is thinking.
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.cs.mutedForeground.withValues(alpha: 0.55);
    final highlight = context.cs.foreground;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // Sweep the highlight from left of the text to right of it.
        final t = _c.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            colors: [base, highlight, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(rect),
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style),
    );
  }
}
