import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'view/constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
      size: AppConstants.initialWindowSize,
      minimumSize: AppConstants.minWindowSize,
      center: true,
      title: AppConstants.appNameAr,
      titleBarStyle: TitleBarStyle.normal,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(AppConstants.minWindowSize);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // startApp() performs all async bootstrapping (database, preferences,
  // repositories, providers) and returns the fully wired widget tree.
  final Widget app = await startApp();

  runApp(app);
}

bool get _isDesktop =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;
