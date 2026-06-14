// lib/core/widgets/dot_pattern.dart

import 'package:flutter/material.dart';

class DotPattern extends StatelessWidget {
  final int rows;
  final int cols;
  final double dotSize;
  final double spacing;
  final Color color;
  final Duration animationDuration;

  const DotPattern({
    super.key,
    this.rows = 8,
    this.cols = 10,
    this.dotSize = 4,
    this.spacing = 8,
    required this.color,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(
          rows * cols,
          (index) {
            // Create a wave animation effect
            final delay = (index % cols) * 50;
            return TweenAnimationBuilder<double>(
              duration: animationDuration,
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, value, child) {
                // Create a pulsing effect based on the delay
                final adjustedValue =
                    ((value * 1000 + delay) % 1000) / 1000;
                final opacity = (0.3 + (0.7 * (1 - (adjustedValue - 0.5).abs() * 2)))
                    .clamp(0.2, 1.0);

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
