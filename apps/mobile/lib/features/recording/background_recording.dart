import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps a recording alive while the phone is not in the tutor's hands.
///
/// - Android: a foreground service with a fixed notification keeps the app
///   (and its EmotiBit sockets) running with the screen off.
/// - iOS: Apple does not allow this kind of local-network streaming in the
///   background, so the screen is kept on for the whole recording.
///
/// Failures are logged and ignored: recording must never fail because of this.
abstract final class BackgroundRecording {
  static bool _initialized = false;

  static Future<void> begin() async {
    try {
      if (Platform.isAndroid) {
        _init();
        final perm = await FlutterForegroundTask.checkNotificationPermission();
        if (perm != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
        if (await FlutterForegroundTask.isRunningService) return;
        await FlutterForegroundTask.startService(
          serviceTypes: [ForegroundServiceTypes.connectedDevice],
          notificationTitle: 'KúuSense',
          notificationText: 'Grabando sesión',
        );
      } else {
        await WakelockPlus.enable();
      }
    } catch (e) {
      debugPrint('background recording not started: $e');
    }
  }

  /// Updates the notification text (Android), e.g. while reconnecting.
  static Future<void> status(String text) async {
    try {
      if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationText: text);
      }
    } catch (e) {
      debugPrint('background status not updated: $e');
    }
  }

  static Future<void> end() async {
    try {
      if (Platform.isAndroid) {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('background recording not stopped: $e');
    }
  }

  static void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'recording',
        channelName: 'Grabación de sesiones',
        channelDescription:
            'Aviso mientras se graba una sesión con el EmotiBit',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: false,
        // Swiping the app away ends the service; the session is recovered
        // on the next start (see SessionUploadQueue).
        stopWithTask: true,
      ),
    );
    _initialized = true;
  }
}
