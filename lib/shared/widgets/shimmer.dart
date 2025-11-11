import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base =
        widget.baseColor ?? cs.surfaceContainerHighest.withValues(alpha: 0.7);
    final highlight =
        widget.highlightColor ?? cs.surface.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = _controller.value;
        return ShaderMask(
          shaderCallback: (rect) {
            final width = rect.width;
            final gradient = LinearGradient(
              begin: Alignment(-1.0 - value, 0),
              end: Alignment(1.0 + value, 0),
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            );
            return gradient.createShader(
              Rect.fromLTWH(-width, 0, rect.width * 3, rect.height),
            );
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}
