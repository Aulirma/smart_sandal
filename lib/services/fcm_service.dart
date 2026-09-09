import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    debugPrint('[FCM] Initializing...');

    // Meminta izin notification
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
              (RemoteMessage message) {
            debugPrint(
              '[FCM] FOREGROUND MESSAGE',
            );

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
          },
        );

    // Token bisa berubah
    FirebaseMessaging.instance.onTokenRefresh.listen(
          (newToken) {
        debugPrint(
          '[FCM] TOKEN REFRESH:',
        );

        debugPrint(newToken);
      },
    );
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