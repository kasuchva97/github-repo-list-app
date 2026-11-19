import 'package:flutter/material.dart';

/// Pulsing placeholder rows shown while the first page loads.
///
/// Gives a sense of the final layout (and feels faster than a lone spinner).
/// Hidden from accessibility services, which get a single "Loading" label.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Semantics(
      label: 'Loading repositories',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: base,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(120.0 + (index % 3) * 40, 14),
                        const SizedBox(height: 8),
                        bar(double.infinity, 10),
                        const SizedBox(height: 6),
                        bar(80, 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.star_border, color: base),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
