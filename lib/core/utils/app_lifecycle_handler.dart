// lib/core/utils/app_lifecycle_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/esp_provider.dart';

class AppLifecycleHandler extends WidgetsBindingObserver {
  final WidgetRef ref;

  AppLifecycleHandler(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-initialise HTTP ESP polling when app resumes
      ref.read(httpEspServiceProvider); // ensure service is alive
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
