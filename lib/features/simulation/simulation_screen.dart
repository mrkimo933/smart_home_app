// lib/features/simulation/simulation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../services/simulation_service.dart';

class SimulationScreen extends ConsumerWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simState = ref.watch(simulationProvider);
    final notifier = ref.read(simulationProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('وضع المحاكاة'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (simState.isRunning)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: const Text(
                'SIM',
                style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning banner
                _WarningBanner(),
                const SizedBox(height: 20),

                // Simulated clock
                if (simState.isRunning) _SimulatedClock(simState),
                if (simState.isRunning) const SizedBox(height: 16),

                // Scenario selector
                const _SectionLabel('اختر السيناريو'),
                const SizedBox(height: 8),
                _ScenarioSelector(simState: simState, notifier: notifier),
                const SizedBox(height: 20),

                // Speed selector
                const _SectionLabel('سرعة المحاكاة'),
                const SizedBox(height: 8),
                _SpeedSelector(simState: simState, notifier: notifier),
                const SizedBox(height: 24),

                // Progress bar
                if (simState.isRunning || simState.progress > 0) ...[
                  _ProgressSection(simState),
                  const SizedBox(height: 20),
                ],

                // Live stats
                if (simState.isRunning && simState.currentData != null) ...[
                  _LiveStats(simState),
                  const SizedBox(height: 20),
                ],

                // Controls
                _ControlButtons(simState: simState, notifier: notifier),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // Simulation watermark
          if (simState.isRunning)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'SIMULATION MODE',
                      style: TextStyle(
                        color: Colors.orange.withAlpha(20),
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'وضع العرض التجريبي - للجنة فقط\nالبيانات المعروضة وهمية وللعرض فقط',
              style: TextStyle(
                  color: Colors.orange, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.primaryBlue,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ScenarioSelector extends StatelessWidget {
  final SimulationState simState;
  final SimulationNotifier notifier;
  const _ScenarioSelector(
      {required this.simState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: SimulationScenario.values.map((s) {
        final selected = simState.scenario == s;
        return GestureDetector(
          onTap: simState.isRunning ? null : () => notifier.setScenario(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryBlue.withAlpha(30)
                  : AppColors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primaryBlue
                    : Colors.white.withAlpha(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _scenarioIcon(s),
                  color: selected ? AppColors.primaryBlue : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  s.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primaryBlue, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _scenarioIcon(SimulationScenario s) {
    switch (s) {
      case SimulationScenario.normalDay:
        return Icons.wb_sunny_rounded;
      case SimulationScenario.highConsumption:
        return Icons.flash_on_rounded;
      case SimulationScenario.savingDay:
        return Icons.eco_rounded;
    }
  }
}

class _SpeedSelector extends StatelessWidget {
  final SimulationState simState;
  final SimulationNotifier notifier;
  const _SpeedSelector({required this.simState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SimulationSpeed.values.map((s) {
        final selected = simState.speed == s;
        return GestureDetector(
          onTap: () => notifier.setSpeed(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryBlue.withAlpha(30)
                  : AppColors.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primaryBlue
                    : Colors.white.withAlpha(20),
              ),
            ),
            child: Text(
              s.label,
              style: TextStyle(
                color: selected ? AppColors.primaryBlue : Colors.white60,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SimulatedClock extends StatelessWidget {
  final SimulationState simState;
  const _SimulatedClock(this.simState);

  @override
  Widget build(BuildContext context) {
    final h = simState.simulatedHour.floor();
    final m = ((simState.simulatedHour - h) * 60).floor();
    final period = h < 12 ? 'صباحاً' : 'مساءً';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final timeStr =
        '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withAlpha(40),
            Colors.purple.withAlpha(30),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryBlue.withAlpha(60), width: 1),
      ),
      child: Column(
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            simState.statusMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final SimulationState simState;
  const _ProgressSection(this.simState);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('تقدم اليوم',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              '${(simState.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: simState.progress,
            minHeight: 10,
            backgroundColor: AppColors.cardColor,
            valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryBlue),
          ),
        ),
      ],
    );
  }
}

class _LiveStats extends StatelessWidget {
  final SimulationState simState;
  const _LiveStats(this.simState);

  @override
  Widget build(BuildContext context) {
    final data = simState.currentData!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('البيانات المحاكاة',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatChip('الجهد', '${data.voltage.toStringAsFixed(0)}V',
                  Colors.blue),
              _StatChip('التيار', '${data.current.toStringAsFixed(1)}A',
                  Colors.orange),
              _StatChip('الطاقة', '${data.power.toStringAsFixed(0)}W',
                  AppColors.primaryBlue),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatChip('الاستهلاك',
                  '${simState.totalKwh.toStringAsFixed(2)} kWh',
                  AppColors.accentGreen),
              _StatChip('التكلفة',
                  '${simState.totalCost.toStringAsFixed(1)} جنيه',
                  Colors.amber),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ],
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final SimulationState simState;
  final SimulationNotifier notifier;
  const _ControlButtons({required this.simState, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!simState.isRunning)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: notifier.start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ المحاكاة',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        if (simState.isRunning && !simState.isPaused) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: notifier.pause,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('إيقاف مؤقت'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withAlpha(40),
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: notifier.stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('إيقاف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(40),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (simState.isPaused) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: notifier.resume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('استئناف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue.withAlpha(40),
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: notifier.stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('إيقاف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withAlpha(40),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (simState.progress > 0 && !simState.isRunning) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: notifier.reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة تعيين'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(15),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
