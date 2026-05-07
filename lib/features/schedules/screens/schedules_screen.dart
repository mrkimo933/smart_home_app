import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../models/schedule.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/mqtt_provider.dart';
import '../../../services/database_service.dart';
import '../widgets/schedule_card.dart';

final schedulesProvider = FutureProvider.autoDispose<List<Schedule>>((ref) async {
  return await DatabaseService().getSchedules();
});

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startScheduleTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startScheduleTimer() {
    // Check every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndExecuteSchedules();
    });
  }

  Future<void> _checkAndExecuteSchedules() async {
    final schedules = await ref.read(schedulesProvider.future);
    final mqtt = ref.read(mqttControllerProvider);
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    // Day index: DateTime.weekday (1=Mon, ..., 7=Sun) -> our repeatDays uses (0=Mon, ..., 6=Sun)
    final dayIndex = now.weekday - 1;

    for (var schedule in schedules) {
      if (!schedule.isEnabled) continue;

      // Check ON trigger
      if (schedule.repeatDays[dayIndex] && 
          schedule.onTime.hour == currentTime.hour && 
          schedule.onTime.minute == currentTime.minute) {
        mqtt.toggleRelay(schedule.deviceId, true);
      }

      // Check OFF trigger
      if (schedule.repeatDays[dayIndex] &&
          schedule.offTime.hour == currentTime.hour &&
          schedule.offTime.minute == currentTime.minute) {
        mqtt.toggleRelay(schedule.deviceId, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesProvider);
    final devices = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الجداول الزمنية', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: schedulesAsync.when(
        data: (schedules) => schedules.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  return ScheduleCard(
                    schedule: schedule,
                    onToggle: (val) async {
                      await DatabaseService().updateSchedule(schedule.copyWith(isEnabled: val));
                      ref.invalidate(schedulesProvider);
                    },
                    onDelete: () async {
                      if (schedule.id != null) {
                        await DatabaseService().deleteSchedule(schedule.id!);
                        ref.invalidate(schedulesProvider);
                      }
                    },
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScheduleSheet(context, devices),
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddScheduleSheet(BuildContext context, List<Device> devices) {
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إضافة أجهزة أولاً')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddScheduleSheet(
        devices: devices,
        onSave: (schedule) async {
          await DatabaseService().insertSchedule(schedule);
          if (!context.mounted) return;
          ref.invalidate(schedulesProvider);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: AppColors.textSecondary.withAlpha((0.5 * 255).toInt())),
          const SizedBox(height: 16),
          const Text(
            'لا توجد جداول زمنية مضافة',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _AddScheduleSheet extends StatefulWidget {
  final List<Device> devices;
  final Function(Schedule) onSave;

  const _AddScheduleSheet({required this.devices, required this.onSave});

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  late Device _selectedDevice;
  TimeOfDay _onTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _offTime = const TimeOfDay(hour: 0, minute: 0);
  final List<bool> _repeatDays = List.generate(7, (_) => true);

  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.devices.first;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إضافة جدول زمني جديد',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<Device>(
            initialValue: _selectedDevice,
            dropdownColor: AppColors.cardColor,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'اختر الجهاز', labelStyle: TextStyle(color: AppColors.textSecondary)),
            items: widget.devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
            onChanged: (val) => setState(() => _selectedDevice = val!),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final isRtl = Directionality.of(context) == TextDirection.rtl;
              final onTile = Expanded(
                child: _TimePickerTile(
                  label: isRtl ? 'وقت التشغيل' : 'ON Time',
                  time: _onTime,
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _onTime);
                    if (picked != null) setState(() => _onTime = picked);
                  },
                ),
              );
              final offTile = Expanded(
                child: _TimePickerTile(
                  label: isRtl ? 'وقت الإيقاف' : 'OFF Time',
                  time: _offTime,
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _offTime);
                    if (picked != null) setState(() => _offTime = picked);
                  },
                ),
              );
              // In RTL: ON (right) then OFF (left) — Row children order is reversed visually
              // Place ON first in the list so it appears on the right in RTL
              return Row(
                children: isRtl
                    ? [onTile, const SizedBox(width: 16), offTile]
                    : [onTile, const SizedBox(width: 16), offTile],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('تكرار في أيام:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.right),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
              return ChoiceChip(
                label: Text(days[index]),
                selected: _repeatDays[index],
                onSelected: (val) => setState(() => _repeatDays[index] = val),
                selectedColor: AppColors.primaryBlue,
                labelStyle: TextStyle(color: _repeatDays[index] ? Colors.white : AppColors.textSecondary),
              );
            }),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => widget.onSave(Schedule(
              deviceId: _selectedDevice.relayId,
              deviceName: _selectedDevice.name,
              onTime: _onTime,
              offTime: _offTime,
              repeatDays: _repeatDays,
            )),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ الجدول'),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.access_time, color: AppColors.primaryBlue, size: 18),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
