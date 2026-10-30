import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('[EMERYS ALARM] BACKGROUND TAP RECEIVED: id=${notificationResponse.id}, actionId=${notificationResponse.actionId}');
  if (notificationResponse.actionId == 'stop_alarm') {
    debugPrint('[EMERYS ALARM] STOP ACTION RECEIVED');
    FlutterLocalNotificationsPlugin().cancel(notificationResponse.id ?? 4001);
    debugPrint('[EMERYS ALARM] Alarm audio stopped');
    debugPrint('[EMERYS ALARM] Emergency notification cancelled');
  }
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    debugPrint('[FCM] Initializing...');

    // Initialize Local Notifications for simulation
    await _initLocalNotifications();

    // Check notification permission for Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('[EMERYS TEST] POST_NOTIFICATIONS granted: $granted');

      // Exact alarm permission check (for Android 13+)
      final canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
      debugPrint('[EMERYS TEST] Can schedule exact notifications: $canScheduleExact');
      
      if (canScheduleExact == false) {
        debugPrint('[EMERYS TEST] Exact alarm permission not granted. Attempting to request (if API supports)...');
        // Note: requestExactAlarmsPermission might not be available in all versions, 
        // usually users are redirected to settings for SCHEDULE_EXACT_ALARM if it's not a TEMPORARY_EXEMPTION.
      }
    }

    // Meminta izin notification (FCM)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      '[FCM] Permission status: '
          '${settings.authorizationStatus}',
    );

    // Ambil FCM token
    final token = await _messaging.getToken();

    debugPrint(
      '[FCM] FCM TOKEN:',
    );

    debugPrint(token ?? 'TOKEN NULL');

    // Notification ketika aplikasi sedang terbuka
    _foregroundSubscription?.cancel();

    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(
              (RemoteMessage message) async {
            debugPrint('[FCM] FOREGROUND MESSAGE');

            debugPrint(
              '[FCM] messageId: ${message.messageId}',
            );

            debugPrint(
              '[FCM] title: ${message.notification?.title}',
            );

            debugPrint(
              '[FCM] body: ${message.notification?.body}',
            );

            debugPrint(
              '[FCM] data: ${message.data}',
            );

            // ==========================================
            // EMERYS FALL ALERT
            // ==========================================
            if (message.data['type'] == 'fall_alert') {
              debugPrint(
                '[EMERYS] FALL ALERT RECEIVED FROM BACKEND',
              );

              await triggerEmergencyFallAlarm();
            }
          },
        );

    // Token bisa berubah
    FirebaseMessaging.instance.onTokenRefresh.listen(
          (newToken) async {
        debugPrint('[FCM] TOKEN REFRESH:');
        debugPrint(newToken);

        try {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null) {
            debugPrint('[FCM] Tidak ada user yang sedang login.');
            return;
          }

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(
            {
              'fcmToken': newToken,
            },
            SetOptions(merge: true),
          );

          debugPrint(
            '[FCM] Token refresh berhasil disimpan untuk user ${user.uid}.',
          );
        } catch (e) {
          debugPrint(
            '[FCM] Gagal menyimpan token refresh: $e',
          );
        }
      },
    );
  }

  Future<void> saveWaliFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          '[FCM] Tidak ada user yang sedang login.',
        );
        return;
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        debugPrint(
          '[FCM] FCM token kosong.',
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'fcmToken': token,
        },
        SetOptions(merge: true),
      );

      debugPrint(
        '[FCM] Token berhasil disimpan '
            'untuk wali ${user.uid}.',
      );
    } catch (e) {
      debugPrint(
        '[FCM] Gagal menyimpan FCM token: $e',
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[FCM] Local notification clicked: ${response.payload}');
        if (response.actionId == 'stop_alarm') {
          debugPrint('[EMERYS ALARM] STOP ACTION RECEIVED');
          _localNotifications.cancel(response.id ?? 4001);
          debugPrint('[EMERYS ALARM] Alarm audio stopped');
          debugPrint('[EMERYS ALARM] Emergency notification cancelled');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // ============================================================
  // EMERGENCY FALL ALARM MODE
  // ============================================================

  Future<void> triggerEmergencyFallAlarm() async {
    debugPrint('[EMERYS TEST] Calling triggerEmergencyFallAlarm()');

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        debugPrint('[EMERYS TEST] POST_NOTIFICATIONS granted: $granted');
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'emerys_emergency_alarm_v2',
        'EMERYS Emergency Alarm',
        channelDescription: 'Emergency channel for continuous fall detection loops',
        importance: Importance.max,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('emerys_alarm'),
        enableVibration: true,
        additionalFlags: Int32List.fromList(<int>[4]),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'stop_alarm',
            'HENTIKAN ALARM',
            cancelNotification: false,
            showsUserInterface: false,
          ),
        ],
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      debugPrint('[EMERYS TEST] Emergency alarm notification started');

      await _localNotifications.show(
        4001,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. Segera periksa kondisi lansia.',
        platformChannelSpecifics,
      );

      debugPrint('[EMERYS TEST] Emergency alarm notification completed');
    } catch (e, stack) {
      debugPrint('[EMERYS TEST] Emergency alarm notification failed: $e');
      debugPrint('[EMERYS TEST] Stack trace: $stack');
    }
  }

  // ============================================================
  // DIAGNOSTIC MODE: IMMEDIATE NOTIFICATION
  // ============================================================

  Future<void> showImmediateDiagnosticNotification() async {
    debugPrint('[EMERYS TEST] Calling immediate diagnostic notification');

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        debugPrint('[EMERYS TEST] POST_NOTIFICATIONS granted: $granted');
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'emerys_diagnostic_v3',
        'EMERYS Diagnostic',
        channelDescription: 'EMERYS notification diagnostic',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      debugPrint('[EMERYS TEST] Immediate diagnostic notification started');
      
      await _localNotifications.show(
        3001,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. Segera periksa kondisi lansia.',
        platformChannelSpecifics,
      );
      
      debugPrint('[EMERYS TEST] Immediate diagnostic notification completed');
    } catch (e, stack) {
      debugPrint('[EMERYS TEST] Immediate diagnostic notification failed: $e');
      debugPrint('[EMERYS TEST] Stack trace: $stack');
    }
  }

  // ============================================================
  // TEST MODE: SIMULATED FALL NOTIFICATION
  // ============================================================

  // TEST MODE ONLY
  // Show an immediate notification to verify if the plugin works at all
  Future<void> showImmediateTestNotification() async {
    debugPrint('[EMERYS TEST] showImmediateTestNotification() CALLED');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emerys_fall_alert_v2',
      'EMERYS Fall Alert',
      channelDescription: 'Notification for detected falls',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      998, // Different ID for immediate test
      'Peringatan Jatuh EMERYS (Immediate)',
      'Lansia terdeteksi mengalami kemungkinan jatuh. Segera periksa kondisi lansia.',
      platformChannelSpecifics,
    );
    debugPrint('[EMERYS TEST] Immediate notification shown');
  }

  //awal manip
  Future<void> showSimulatedFallNotification() async {
    debugPrint(
      '[SIMULASI] Menampilkan notifikasi jatuh.',
    );
    const AndroidNotificationDetails
    androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'emerys_simulation_fall_v2',
      'EMERYS Simulasi Jatuh',
      channelDescription:
      'Notifikasi simulasi jatuh untuk pengujian aplikasi',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('emerys_alarm'),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    const NotificationDetails
    platformChannelSpecifics =
    NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    try {
      await _localNotifications.show(
        5001,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. '
            'Segera periksa kondisi lansia.',
        platformChannelSpecifics,
        payload: 'simulated_fall',
      );
      debugPrint(
        '[SIMULASI] Notifikasi jatuh berhasil ditampilkan.',
      );
    } catch (e, stack) {
      debugPrint(
        '[SIMULASI] Gagal menampilkan notifikasi: $e',
      );
      debugPrint(
        '[SIMULASI] Stack trace: $stack',
      );
    }
  }
  //akhir manip

  // TEST MODE ONLY
  // TODO: Replace scheduled notification with real EMERYS fall detection event.
  Future<void> scheduleTestFallNotification() async {
    debugPrint('[EMERYS TEST] scheduleTestFallNotification() CALLED');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emerys_fall_alert_v2', // Updated ID to ensure fresh channel config
      'EMERYS Fall Alert',
      channelDescription: 'Notification for detected falls',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(minutes: 1));

      debugPrint('[EMERYS TEST] Current time: $now');
      debugPrint('[EMERYS TEST] Scheduled time: $scheduledTime');

      await _localNotifications.zonedSchedule(
        999, // Unique ID for simulated fall alert
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. Segera periksa kondisi lansia.',
        scheduledTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('[EMERYS TEST] Notification scheduled successfully');

      // Show immediate notification for diagnostic purposes
      await showImmediateTestNotification();

      // Check pending notifications
      final pending = await _localNotifications.pendingNotificationRequests();
      debugPrint('[EMERYS TEST] Pending notifications count: ${pending.length}');
      for (var req in pending) {
        debugPrint('[EMERYS TEST] Pending ID: ${req.id}, Title: ${req.title}');
      }
    } catch (e, stack) {
      debugPrint('[EMERYS TEST] Failed to schedule notification: $e');
      debugPrint('[EMERYS TEST] Stack trace: $stack');
    }
  }

  Future<void> cancelTestFallNotification() async {
    await _localNotifications.cancel(999);
    debugPrint('[EMERYS TEST] Simulated fall notification cancelled');
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint(
        '[FCM] Gagal mengambil token: $e',
      );

      return null;
    }
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
  }
}