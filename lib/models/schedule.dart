import 'package:flutter/material.dart';
import 'dart:convert';

class Schedule {
  final int? id;
  final int deviceId;
  final String deviceName;
  final TimeOfDay onTime;
  final TimeOfDay offTime;
  final List<bool> repeatDays; // index 0 = Mon, ..., 6 = Sun
  final bool isEnabled;

  Schedule({
    this.id,
    required this.deviceId,
    required this.deviceName,
    required this.onTime,
    required this.offTime,
    required this.repeatDays,
    this.isEnabled = true,
  });

  Schedule copyWith({
    int? id,
    int? deviceId,
    String? deviceName,
    TimeOfDay? onTime,
    TimeOfDay? offTime,
    List<bool>? repeatDays,
    bool? isEnabled,
  }) {
    return Schedule(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      onTime: onTime ?? this.onTime,
      offTime: offTime ?? this.offTime,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'on_hour': onTime.hour,
      'on_minute': onTime.minute,
      'off_hour': offTime.hour,
      'off_minute': offTime.minute,
      'repeat_days': jsonEncode(repeatDays),
      'is_enabled': isEnabled ? 1 : 0,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      deviceId: map['device_id'],
      deviceName: map['device_name'],
      onTime: TimeOfDay(hour: map['on_hour'], minute: map['on_minute']),
      offTime: TimeOfDay(hour: map['off_hour'], minute: map['off_minute']),
      repeatDays: List<bool>.from(jsonDecode(map['repeat_days'])),
      isEnabled: map['is_enabled'] == 1,
    );
  }
}
