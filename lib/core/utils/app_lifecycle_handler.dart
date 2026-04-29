// lib/core/utils/app_lifecycle_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/mqtt_provider.dart';

class AppLifecycleHandler extends WidgetsBindingObserver {
  final WidgetRef ref;

  AppLifecycleHandler(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect MQTT if needed
      ref.read(mqttServiceProvider).connect();
    } else if (state == AppLifecycleState.paused) {
      // Could keep alive or perform cleanup
    }
  }
}

final appLifecycleProvider = Provider.family<AppLifecycleHandler, WidgetRef>((ref, widgetRef) {
  final handler = AppLifecycleHandler(widgetRef);
  WidgetsBinding.instance.addObserver(handler);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(handler));
  return handler;
});
