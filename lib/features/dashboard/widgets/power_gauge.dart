// lib/features/dashboard/widgets/power_gauge.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PowerGauge extends StatelessWidget {
  final double watts;
  final double maxWatts;

  const PowerGauge({
    super.key,
    required this.watts,
    this.maxWatts = 3000.0,
  });

  Color _getGaugeColor(double value) {
    if (value < 500) return AppColors.accentTeal;
    if (value < 1500) return AppColors.accentOrange;
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getGaugeColor(watts);
    final percentage = (watts / maxWatts).clamp(0.0, 1.0);

    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track
          CustomPaint(
            size: const Size(200, 200),
            painter: GaugePainter(
              percentage: 1.0,
              color: AppColors.cardColor,
              strokeWidth: 15,
            ),
          ),
          // Filled Track
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percentage),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCirc,
            builder: (context, val, child) {
              return CustomPaint(
                size: const Size(200, 200),
                painter: GaugePainter(
                  percentage: val,
                  color: color,
                  strokeWidth: 15,
                ),
              );
            },
          ),
          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: watts),
                duration: const Duration(milliseconds: 800),
                builder: (context, val, child) {
                  return Text(
                    val.toInt().toString(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: color.withAlpha((0.5 * 255).toInt()),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Text(
                'WATTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final double strokeWidth;

  GaugePainter({
    required this.percentage,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;
    final sweepAngle = totalSweep * percentage;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
