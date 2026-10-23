import 'package:flutter/material.dart';

/// Loading placeholders (2026-10-23, user: the dashboard showed empty
/// numbers until the data came): grey boxes in the shape of what's coming,
/// with a soft light sweeping across. Nothing in them looks like data.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  /// The placeholder shapes ([SkeletonBox]es); the sweep runs over all of them.
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final light = Color.lerp(base, scheme.surface, 0.6)!;
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = _sweep.value * 3 - 1; // −1 … 2: from off the left to off the right
            return LinearGradient(
              colors: [base, light, base],
              stops: [t - 0.3, t, t + 0.3].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(rect);
          },
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// One grey rounded box inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// A card-shaped placeholder: a title bar and [lines] text lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;

  /// Fixed height instead of the lines (e.g. a chart).
  final double? height;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 140, height: 16),
              const SizedBox(height: 16),
              if (height != null)
                SkeletonBox(height: height!)
              else
                for (var i = 0; i < lines; i++) ...[
                  // Lines of different lengths look like text.
                  FractionallySizedBox(widthFactor: i.isEven ? 1 : 0.7, child: const SkeletonBox(height: 12)),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      );
}
