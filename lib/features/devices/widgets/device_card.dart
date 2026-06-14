// lib/features/devices/widgets/device_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../models/device.dart';
import '../../../providers/esp_provider.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/system_provider.dart';
import '../../../core/utils/electricity_calculator.dart';
import 'device_edit_dialog.dart';

class DeviceCard extends ConsumerWidget {
  final Device device;
  final bool isMqttConnected;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isMqttConnected,
  });

  IconData _getIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'lamp':
        return Icons.light_outlined;
      case 'ac':
        return Icons.air_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'fan':
        return Icons.mode_fan_off_rounded;
      case 'fridge':
        return Icons.kitchen_rounded;
      case 'washer':
      case 'washing_machine':
        return Icons.local_laundry_service_rounded;
      case 'pc':
        return Icons.computer_rounded;
      case 'router':
        return Icons.router_rounded;
      case 'heater':
      case 'water_heater':
        return Icons.hot_tub_rounded;
      case 'microwave':
        return Icons.microwave_rounded;
      case 'coffee_maker':
        return Icons.coffee_maker_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  // ── Feature 6: Timer bottom sheet ─────────────────────────────────────────
  void _showTimerSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String unit = 'minutes';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Timer for ${device.name}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Cancel existing timer button
              if (device.timerMinutes != null)
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(httpEspServiceProvider)
                        .publishRelayCommand(device.relayId, false);
                    ref
                        .read(devicesProvider.notifier)
                        .clearDeviceTimer(device.id);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.timer_off_rounded,
                      color: Colors.redAccent),
                  label: const Text('Cancel Current Timer',
                      style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent)),
                ),
              if (device.timerMinutes != null) const SizedBox(height: 16),
              // Quick presets
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in [
                    ('30m', 30),
                    ('1hr', 60),
                    ('2hr', 120),
                    ('3hr', 180),
                    ('4hr', 240),
                    ('6hr', 360),
                    ('8hr', 480),
                  ])
                    _TimerPresetChip(
                      label: preset.$1,
                      onTap: () {
                        _applyTimer(ref, preset.$2);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Custom',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Duration',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withAlpha((0.05 * 255).toInt()),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    dropdownColor: AppColors.cardColor,
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    onChanged: (val) =>
                        setSheetState(() => unit = val ?? 'minutes'),
                    items: ['minutes', 'hours'].map((u) {
                      return DropdownMenuItem(value: u, child: Text(u));
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if (val != null && val > 0) {
                    final minutes =
                        unit == 'hours' ? val * 60 : val;
                    _applyTimer(ref, minutes);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Set Timer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyTimer(WidgetRef ref, int minutes) {
    ref.read(httpEspServiceProvider).publishRelayCommand(device.relayId, true);
    ref.read(devicesProvider.notifier).setDeviceTimer(device.id, minutes);
  }

  // ── Feature 7: Run by budget bottom sheet ─────────────────────────────────
  void _showRunByBudgetSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    double? previewHours;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Run ${device.name} by Budget 💰',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${device.wattage.toInt()}W · ${ElectricityCalculator.calculateCost(device.wattage / 1000).toStringAsFixed(3)} EGP/hr',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  final budget = double.tryParse(val);
                  if (budget != null && budget > 0) {
                    setSheetState(() {
                      previewHours = ElectricityCalculator.hoursForBudget(
                          device.wattage, budget);
                    });
                  } else {
                    setSheetState(() => previewHours = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Budget (EGP)',
                  labelStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primaryBlue),
                  suffixText: 'EGP',
                  suffixStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withAlpha((0.05 * 255).toInt()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (previewHours != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primaryBlue.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryBlue
                            .withAlpha((0.3 * 255).toInt())),
                  ),
                  child: Text(
                    '${controller.text} EGP ≈ ${_formatHours(previewHours!)} of ${device.name}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: previewHours != null
                    ? () {
                        final budget = double.parse(controller.text);
                        final minutes = (previewHours! * 60).round();
                        ref
                            .read(httpEspServiceProvider)
                            .publishRelayCommand(device.relayId, true);
                        ref
                            .read(devicesProvider.notifier)
                            .setRunByBudget(device.id, minutes, budget);
                        Navigator.pop(ctx);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  previewHours != null
                      ? 'Start (${_formatHours(previewHours!)})'
                      : 'Enter Budget',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  // Timer countdown label
  String? _timerLabel() {
    if (!device.isOn) return null;
    if (device.timerMinutes == null || device.timerStartTime == null) {
      return null;
    }
    final elapsed =
        DateTime.now().difference(device.timerStartTime!).inMinutes;
    final remaining = device.timerMinutes! - elapsed;
    if (remaining <= 0) return null;
    final prefix = device.runBudgetEGP != null
        ? '💰 ${device.runBudgetEGP!.toStringAsFixed(0)} EGP — '
        : '⏰ ';
    return '${prefix}Turns off in ${_formatMinutes(remaining)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool active = device.isOn;
    final accentColor =
        active ? const Color(0xFF00B4D8) : AppColors.textSecondary;
    final timerLabel = _timerLabel();

    // Feature 1: Zero power when relay is OFF
    final displayWatts = active ? device.wattage.toInt() : 0;

    return Dismissible(
      key: Key(device.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Device?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'Are you sure you want to delete this device?',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes')),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(devicesProvider.notifier).deleteDevice(device.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha((0.2 * 255).toInt()),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.redAccent, size: 30),
      ),
      child: GestureDetector(
        onLongPress: () => showDialog(
          context: context,
          builder: (context) => DeviceEditDialog(device: device),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: active
                  ? AppColors.primaryBlue.withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00B4D8).withAlpha((0.15 * 255).toInt())
                          : Colors.white.withAlpha((0.05 * 255).toInt()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getIcon(device.icon),
                        color: accentColor, size: 28),
                  ),
                  // Feature 6 & 7: action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Timer button
                      IconButton(
                        icon: Icon(
                          Icons.timer_outlined,
                          color: device.timerMinutes != null
                              ? Colors.orangeAccent
                              : Colors.white38,
                          size: 20,
                        ),
                        onPressed: isMqttConnected
                            ? () => _showTimerSheet(context, ref)
                            : null,
                        tooltip: 'Set Timer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                      // Run by budget button
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.white38, size: 20),
                        onPressed: isMqttConnected
                            ? () => _showRunByBudgetSheet(context, ref)
                            : null,
                        tooltip: 'Run by Budget',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                      Tooltip(
                        message: isMqttConnected ? '' : 'اتصل بالـ ESP أولاً',
                        child: Builder(builder: (context) {
                          final protectedRelays =
                              ref.watch(protectedRelaysProvider);
                          final isProtected =
                              protectedRelays.contains(device.relayId);

                          return GestureDetector( // ignore: avoid_returning_widgets
                            onTap: isMqttConnected
                                ? () async {
                                    final turningOn = !active;

                                    // Block re-enable if relay is protection-locked.
                                    if (turningOn && isProtected) {
                                      final confirmed =
                                          await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor:
                                              const Color(0xFF1D1E33),
                                          title: const Row(children: [
                                            Text('⚠️ ',
                                                style: TextStyle(
                                                    fontSize: 20)),
                                            Text('تحذير: دائرة قصيرة',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                          content: Text(
                                            'تم اكتشاف دائرة قصيرة في "${device.name}" وتم قطعه تلقائياً للحماية.\n\n'
                                            'هل أنت متأكد أن المشكلة اتصلحت وتريد إعادة التشغيل؟',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context, false),
                                              child: const Text('إلغاء',
                                                  style: TextStyle(
                                                      color: Colors
                                                          .white54)),
                                            ),
                                            ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.red),
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context, true),
                                              child: const Text(
                                                  'إلغاء الحماية وتشغيل',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true) return;

                                      // User confirmed — remove the lock.
                                      final current =
                                          ref.read(protectedRelaysProvider);
                                      ref
                                          .read(protectedRelaysProvider
                                              .notifier)
                                          .state = Set.from(current)
                                        ..remove(device.relayId);
                                    }

                                    ref
                                        .read(httpEspServiceProvider)
                                        .publishRelayCommand(
                                            device.relayId, turningOn);
                                    ref
                                        .read(devicesProvider.notifier)
                                        .toggleDevice(
                                            device.relayId, turningOn);
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 52,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: isProtected && !active
                                    ? Colors.red.shade900
                                    : active
                                        ? const Color(0xFF00B4D8)
                                        : (isMqttConnected
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade900),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00B4D8)
                                            .withAlpha((0.4 * 255).toInt()),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: active
                                  ? AlignmentDirectional.centerEnd
                                  : AlignmentDirectional.centerStart,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMqttConnected
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );   // GestureDetector
                      }),    // Builder
                    ),       // Tooltip
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          active ? AppColors.accentGreen : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.accentGreen
                                    .withAlpha((0.6 * 255).toInt()),
                                blurRadius: 6,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Feature 1: show 0W when off
                  Text(
                    '${displayWatts}W',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).toInt()),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    active
                        ? '${ElectricityCalculator.calculateCost(device.wattage / 1000).toStringAsFixed(2)} EGP/hr'
                        : 'OFF',
                    style: TextStyle(
                      color: active ? Colors.orangeAccent : Colors.white30,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Timer countdown label (Feature 6 & 7)
              if (timerLabel != null)
                Text(
                  timerLabel,
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                )
              else
                Text(
                  active
                      ? 'شغال منذ ${_formatMinutes(device.totalOnMinutesToday)}'
                      : 'مطفي',
                  style: TextStyle(
                      color: Colors.white.withAlpha((0.6 * 255).toInt()), fontSize: 13),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      (device.totalOnMinutesToday / (8 * 60)).clamp(0.0, 1.0),
                  backgroundColor:
                      Colors.white.withAlpha((0.05 * 255).toInt()),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    active ? const Color(0xFF00B4D8) : Colors.white30,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimerPresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withAlpha((0.15 * 255).toInt()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.primaryBlue.withAlpha((0.4 * 255).toInt())),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
    );
  }
}
