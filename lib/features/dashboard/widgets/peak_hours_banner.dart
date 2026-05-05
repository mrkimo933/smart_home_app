// lib/features/dashboard/widgets/peak_hours_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/peak_hours_checker.dart';

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
                colors: [Color(0xFFD93025), Color(0xFFFF6B35)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFFAA00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              );

        return FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(gradient: gradient),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'وقت الذروة - الاستهلاك العالي الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        PeakHoursChecker.peakEndTimeAr(),
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
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
