// lib/features/dashboard/widgets/quick_actions_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/device.dart';
import '../../../providers/devices_provider.dart';
import '../../../providers/esp_provider.dart';
import '../../../services/notification_service.dart';

class QuickActionsBar extends ConsumerWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStatusProvider).value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1D1E33),
                const Color(0xFF1D1E33).withAlpha(220),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryBlue.withAlpha(40),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _QuickActionButton(
                label: 'فصل كل حاجة',
                icon: Icons.power_settings_new_rounded,
                color: const Color(0xFFFF4B4B),
                isEnabled: isConnected,
                onTap: () => _showConfirmDialog(
                  context: context,
                  title: 'فصل كل الأجهزة',
                  message: 'هتفصل كل الأجهزة، متأكد؟',
                  onConfirm: () => _turnOffAll(ref),
                ),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                label: 'الضروري بس',
                icon: Icons.shield_rounded,
                color: const Color(0xFFFF9500),
                isEnabled: isConnected,
                onTap: () => _showConfirmDialog(
                  context: context,
                  title: 'الأجهزة الضرورية فقط',
                  message:
                      'هيفضل شغال الأجهزة الضرورية بس،\nباقي الأجهزة هتتفصل. متأكد؟',
                  onConfirm: () => _essentialOnly(ref),
                ),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                label: 'وضع الليل',
                icon: Icons.bedtime_rounded,
                color: const Color(0xFF7C5CBF),
                isEnabled: isConnected,
                onTap: () => _showConfirmDialog(
                  context: context,
                  title: 'وضع الليل',
                  message:
                      'وضع الليل: هيفصل كل حاجة ما عدا\nالأجهزة الضرورية. متأكد؟',
                  onConfirm: () => _nightMode(ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: Colors.white70, height: 1.5)),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لأ', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('نعم', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _turnOffAll(WidgetRef ref) {
    final devices = ref.read(devicesProvider);
    final espService = ref.read(httpEspServiceProvider);
    for (final d in devices) {
      if (d.isOn) {
        espService.publishRelayCommand(d.relayId, false);
        ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
      }
    }
    NotificationService().showNotification(
      id: 700,
      title: '🔴 تم فصل الأجهزة',
      body: 'تم فصل كل الأجهزة بنجاح',
    );
  }

  void _essentialOnly(WidgetRef ref) {
    final devices = ref.read(devicesProvider);
    final espService = ref.read(httpEspServiceProvider);
    for (final d in devices) {
      if (d.isOn && d.priority != DevicePriority.essential) {
        espService.publishRelayCommand(d.relayId, false);
        ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
      }
    }
    NotificationService().showNotification(
      id: 701,
      title: '🟡 الأجهزة الضرورية فقط',
      body: 'تم تشغيل الأجهزة الضرورية فقط',
    );
  }

  void _nightMode(WidgetRef ref) {
    final devices = ref.read(devicesProvider);
    final espService = ref.read(httpEspServiceProvider);
    for (final d in devices) {
      if (d.isOn && d.priority != DevicePriority.essential) {
        espService.publishRelayCommand(d.relayId, false);
        ref.read(devicesProvider.notifier).toggleDevice(d.relayId, false);
      }
    }
    NotificationService().showNotification(
      id: 702,
      title: '🌙 وضع الليل',
      body: 'تم تفعيل وضع الليل',
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.isEnabled ? widget.color : Colors.grey.shade700;

    return Expanded(
      child: Tooltip(
        message: widget.isEnabled ? '' : 'اتصل بالـ ESP أولاً',
        child: GestureDetector(
          onTapDown: widget.isEnabled ? (_) => _ctrl.forward() : null,
          onTapUp: widget.isEnabled
              ? (_) {
                  _ctrl.reverse();
                  widget.onTap();
                }
              : null,
          onTapCancel: () => _ctrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: effectiveColor.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: effectiveColor.withAlpha(80), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: effectiveColor, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.isEnabled ? Colors.white : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
