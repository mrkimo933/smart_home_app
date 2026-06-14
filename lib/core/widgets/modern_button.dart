// lib/core/widgets/modern_button.dart

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ModernButtonVariant {
  primary,
  secondary,
  outlined,
  ghost,
}

class ModernButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final ModernButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final EdgeInsetsGeometry padding;

  const ModernButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ModernButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
  });

  Color _getBackgroundColor() {
    switch (variant) {
      case ModernButtonVariant.primary:
        return enabled ? AppColors.primaryBlue : AppColors.textTertiary;
      case ModernButtonVariant.secondary:
        return enabled ? AppColors.accentMagenta : AppColors.textTertiary;
      case ModernButtonVariant.outlined:
      case ModernButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    switch (variant) {
      case ModernButtonVariant.primary:
      case ModernButtonVariant.secondary:
        return Colors.white;
      case ModernButtonVariant.outlined:
        return enabled ? AppColors.primaryBlue : AppColors.textTertiary;
      case ModernButtonVariant.ghost:
        return enabled ? AppColors.textPrimary : AppColors.textTertiary;
    }
  }

  Border? _getBorder() {
    if (variant == ModernButtonVariant.outlined) {
      return Border.all(
        color: enabled ? AppColors.primaryBlue : AppColors.textTertiary,
        width: 2,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && !isLoading) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor()),
            ),
          )
        else
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _getForegroundColor(),
            ),
          ),
        if (isLoading) ...[
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _getForegroundColor(),
            ),
          ),
        ],
      ],
    );

    final buttonWidget = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        border: _getBorder(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: variant == ModernButtonVariant.primary && enabled
            ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : variant == ModernButtonVariant.secondary && enabled
                ? [
                    BoxShadow(
                      color: AppColors.accentMagenta.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
      ),
      child: child,
    );

    if (!enabled) {
      return buttonWidget;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: buttonWidget,
      ),
    );
  }
}

class ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final bool enabled;

  const ModernIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 24,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor ?? (enabled 
                ? AppColors.primaryBlue.withOpacity(0.15)
                : AppColors.textTertiary.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color ?? (enabled 
                ? AppColors.primaryBlue 
                : AppColors.textTertiary),
            size: size,
          ),
        ),
      ),
    );
  }
}
