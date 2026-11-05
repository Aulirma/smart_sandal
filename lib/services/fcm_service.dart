import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ============================================================
// BACKGROUND / TERMINATED HANDLERS
// Harus top-level function (bukan di dalam class).
// ============================================================

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
    '[EMERYS ALARM] BACKGROUND TAP RECEIVED: '
    'id=${notificationResponse.id}, '
    'actionId=${notificationResponse.actionId}',
  );

  if (notificationResponse.actionId == 'stop_alarm') {
    debugPrint('[EMERYS ALARM] STOP ACTION RECEIVED');
    FlutterLocalNotificationsPlugin().cancel(notificationResponse.id ?? 4001);
    debugPrint('[EMERYS ALARM] Emergency notification cancelled');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('[FCM] BACKGROUND MESSAGE: ${message.data}');

  // Pesan yang punya payload "notification" sudah ditampilkan
  // otomatis oleh sistem Android, jadi tidak perlu ditampilkan lagi.
  if (message.notification != null) return;

  final plugin = FlutterLocalNotificationsPlugin();

  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  if (message.data['type'] == 'fall_alert') {
    await plugin.show(
      4001,
      'Peringatan Jatuh EMERYS',
      'Lansia terdeteksi mengalami kemungkinan jatuh. '
          'Segera periksa kondisi lansia.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'emerys_emergency_alarm_v2',
          'EMERYS Emergency Alarm',
          channelDescription:
              'Emergency channel for continuous fall detection loops',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('emerys_alarm'),
          enableVibration: true,
          additionalFlags: Int32List.fromList(<int>[4]),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              'stop_alarm',
              'HENTIKAN ALARM',
              cancelNotification: false,
              showsUserInterface: false,
            ),
          ],
        ),
      ),
    );
    return;
  }

  final title = message.data['title']?.toString() ?? 'EMERYS';
  final body = message.data['message']?.toString() ?? '';

  await plugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'emerys_general',
        'EMERYS Notifikasi',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// ============================================================
// FCM SERVICE
// ============================================================

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<User?>? _authSubscription;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    debugPrint('[FCM] Initializing...');

    await _initLocalNotifications();

    // Izin notifikasi Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('[EMERYS TEST] POST_NOTIFICATIONS granted: $granted');

      final canScheduleExact = await androidPlugin
          ?.canScheduleExactNotifications();
      debugPrint(
        '[EMERYS TEST] Can schedule exact notifications: $canScheduleExact',
      );
    }

    // Izin notifikasi FCM
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // Ambil FCM token
    final token = await _messaging.getToken();

    debugPrint('[FCM] FCM TOKEN:');
    debugPrint(token ?? 'TOKEN NULL');

    // Simpan token sekarang kalau sudah login,
    // dan simpan lagi setiap kali user login.
    await saveWaliFcmToken();

    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        saveWaliFcmToken();
      }
    });

    // Notifikasi ketika aplikasi sedang terbuka
    _foregroundSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) async {
      debugPrint('[FCM] FOREGROUND MESSAGE');
      debugPrint('[FCM] messageId: ${message.messageId}');
      debugPrint('[FCM] title: ${message.notification?.title}');
      debugPrint('[FCM] body: ${message.notification?.body}');
      debugPrint('[FCM] data: ${message.data}');

      if (message.data['type'] == 'fall_alert') {
        debugPrint('[EMERYS] FALL ALERT RECEIVED FROM BACKEND');
        await triggerEmergencyFallAlarm();
      } else {
        await _showGenericNotification(message);
      }
    });

    // Token bisa berubah
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
      newToken,
    ) async {
      debugPrint('[FCM] TOKEN REFRESH:');
      debugPrint(newToken);

      try {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          debugPrint('[FCM] Tidak ada user yang sedang login.');
          return;
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': newToken,
        }, SetOptions(merge: true));

        debugPrint(
          '[FCM] Token refresh berhasil disimpan untuk user ${user.uid}.',
        );
      } catch (e) {
        debugPrint('[FCM] Gagal menyimpan token refresh: $e');
      }
    });
  }

  // ============================================================
  // SIMPAN TOKEN WALI KE FIRESTORE
  // ============================================================

  Future<void> saveWaliFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('[FCM] Tidak ada user yang sedang login.');
        return;
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] FCM token kosong.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));

      debugPrint('[FCM] Token berhasil disimpan untuk wali ${user.uid}.');
    } catch (e) {
      debugPrint('[FCM] Gagal menyimpan FCM token: $e');
    }
  }

  // ============================================================
  // LOCAL NOTIFICATIONS
  // ============================================================

  Future<void> _initLocalNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[FCM] Local notification clicked: ${response.payload}');

        if (response.actionId == 'stop_alarm') {
          debugPrint('[EMERYS ALARM] STOP ACTION RECEIVED');
          _localNotifications.cancel(response.id ?? 4001);
          debugPrint('[EMERYS ALARM] Emergency notification cancelled');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // Notifikasi umum untuk tipe selain fall_alert
  // (low_battery, unstable_activity, daily_report, dll.)
  Future<void> _showGenericNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'EMERYS';

    final body =
        message.notification?.body ?? message.data['message']?.toString() ?? '';

    try {
      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emerys_general',
            'EMERYS Notifikasi',
            channelDescription: 'Notifikasi umum aplikasi EMERYS',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] Gagal menampilkan notifikasi umum: $e');
    }
  }

  // ============================================================
  // EMERGENCY FALL ALARM MODE
  // ============================================================

  Future<void> triggerEmergencyFallAlarm() async {
    debugPrint('[EMERYS TEST] Calling triggerEmergencyFallAlarm()');

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidPlugin?.requestNotificationsPermission();
        debugPrint('[EMERYS TEST] POST_NOTIFICATIONS granted: $granted');
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'emerys_emergency_alarm_v2',
            'EMERYS Emergency Alarm',
            channelDescription:
                'Emergency channel for continuous fall detection loops',
            importance: Importance.max,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('emerys_alarm'),
            enableVibration: true,
            additionalFlags: Int32List.fromList(<int>[4]),
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'stop_alarm',
                'HENTIKAN ALARM',
                cancelNotification: false,
                showsUserInterface: false,
              ),
            ],
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      debugPrint('[EMERYS TEST] Emergency alarm notification started');

      await _localNotifications.show(
        4001,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. '
            'Segera periksa kondisi lansia.',
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
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
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

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      debugPrint('[EMERYS TEST] Immediate diagnostic notification started');

      await _localNotifications.show(
        3001,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. '
            'Segera periksa kondisi lansia.',
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

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      998,
      'Peringatan Jatuh EMERYS (Immediate)',
      'Lansia terdeteksi mengalami kemungkinan jatuh. '
          'Segera periksa kondisi lansia.',
      platformChannelSpecifics,
    );

    debugPrint('[EMERYS TEST] Immediate notification shown');
  }

  Future<void> showSimulatedFallNotification() async {
    debugPrint('[SIMULASI] Menampilkan notifikasi jatuh.');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
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
          sound: RawResourceAndroidNotificationSound('emerys_alarm'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
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

      debugPrint('[SIMULASI] Notifikasi jatuh berhasil ditampilkan.');
    } catch (e, stack) {
      debugPrint('[SIMULASI] Gagal menampilkan notifikasi: $e');
      debugPrint('[SIMULASI] Stack trace: $stack');
    }
  }

  // TEST MODE ONLY
  // TODO: Replace scheduled notification with real EMERYS fall detection event.
  Future<void> scheduleTestFallNotification() async {
    debugPrint('[EMERYS TEST] scheduleTestFallNotification() CALLED');

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

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(minutes: 1));

      debugPrint('[EMERYS TEST] Current time: $now');
      debugPrint('[EMERYS TEST] Scheduled time: $scheduledTime');

      await _localNotifications.zonedSchedule(
        999,
        'Peringatan Jatuh EMERYS',
        'Lansia terdeteksi mengalami kemungkinan jatuh. '
            'Segera periksa kondisi lansia.',
        scheduledTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('[EMERYS TEST] Notification scheduled successfully');

      await showImmediateTestNotification();

      final pending = await _localNotifications.pendingNotificationRequests();
      debugPrint(
        '[EMERYS TEST] Pending notifications count: ${pending.length}',
      );
      for (final req in pending) {
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

  // ============================================================
  // HELPERS
  // ============================================================

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Gagal mengambil token: $e');
      return null;
    }
  }

  void dispose() {
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
