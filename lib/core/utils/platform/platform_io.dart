// IO-only platform helpers.
//
// IMPORTANT: Don't import this file from code that might run on the web.
// Use it only behind a `kIsWeb == false` guard.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:io' as io;

/// True when running on a desktop OS (Windows/macOS/Linux).
bool get isDesktop => io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux;
