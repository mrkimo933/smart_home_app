// lib/core/widgets/gradient_background.dart

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry? begin;
  final AlignmentGeometry? end;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin,
    this.end,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? [
            AppColors.background,
            Color.lerp(AppColors.background, AppColors.primaryBlue, 0.05)!,
          ],
          begin: begin ?? Alignment.topLeft,
          end: end ?? Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class AccentGradient extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final double intensity;

  const AccentGradient({
    super.key,
    required this.child,
    required this.accentColor,
    this.intensity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.cardColor,
            Color.lerp(AppColors.cardColor, accentColor, intensity)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
