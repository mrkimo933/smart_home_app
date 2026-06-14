// lib/features/dashboard/widgets/peak_hours_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/peak_hours_checker.dart';
import '../../../core/constants/app_colors.dart';

class PeakHoursBanner extends ConsumerStatefulWidget {
  const PeakHoursBanner({super.key});

  @override
  ConsumerState<PeakHoursBanner> createState() => _PeakHoursBannerState();
}

class _PeakHoursBannerState extends ConsumerState<PeakHoursBanner>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  PeakStatus? _lastStatus;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peakAsync = ref.watch(peakStatusProvider);

    return peakAsync.when(
      data: (status) {
        // Reset dismiss when peak window changes
        if (status != _lastStatus) {
          _lastStatus = status;
          _dismissed = false;
          if (status != PeakStatus.none) {
            _animCtrl.forward(from: 0);
          }
        }

        if (status == PeakStatus.none || _dismissed) {
          return const SizedBox.shrink();
        }

        final isAfternoon = status == PeakStatus.afternoonPeak;
        final gradient = isAfternoon
            ? const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFD946EF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isAfternoon ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'وقت الذروة - الاستهلاك العالي الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PeakHoursChecker.peakEndTimeAr(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
