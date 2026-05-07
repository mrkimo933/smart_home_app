import 'package:flutter/material.dart';

enum NotificationType {
  overcurrent,
  shortCircuit,
  budgetAlert,
  voltageWarning,
  scheduleExecuted,
  morningReminder,
  general,
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final String? deviceName;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.deviceName,
    required this.timestamp,
    this.isRead = false,
  });

  String get emoji {
    switch (type) {
      case NotificationType.overcurrent:
        return '⚠️';
      case NotificationType.shortCircuit:
        return '⚡';
      case NotificationType.budgetAlert:
        return '💰';
      case NotificationType.voltageWarning:
        return '🔌';
      case NotificationType.scheduleExecuted:
        return '🕐';
      case NotificationType.morningReminder:
        return '🌅';
      case NotificationType.general:
        return '🔔';
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.overcurrent:
      case NotificationType.shortCircuit:
        return const Color(0xFFFF4B4B);
      case NotificationType.budgetAlert:
        return const Color(0xFFFFA500);
      case NotificationType.voltageWarning:
        return const Color(0xFFFFD700);
      case NotificationType.scheduleExecuted:
      case NotificationType.morningReminder:
      case NotificationType.general:
        return const Color(0xFF00B4D8);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}
