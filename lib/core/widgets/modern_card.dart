// lib/core/widgets/modern_card.dart

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final List<Color>? gradientColors;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;
  final VoidCallback? onTap;
  final Border? border;

  const ModernCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.gradientColors,
    this.gradientBegin,
    this.gradientEnd,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    final decoration = BoxDecoration(
      color: gradientColors == null ? (backgroundColor ?? AppColors.cardColor) : null,
      gradient: gradientColors != null
          ? LinearGradient(
              colors: gradientColors!,
              begin: gradientBegin ?? Alignment.topLeft,
              end: gradientEnd ?? Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}

class ModernStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final IconData? icon;
  final Color? backgroundColor;
  final List<Color>? gradientColors;

  const ModernStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.icon,
    this.backgroundColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      backgroundColor: backgroundColor,
      gradientColors: gradientColors,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              if (icon != null)
                Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
