import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'bottom_navigation.dart';   // shell dashboard WALI yang sudah ada
import 'elderly_home_page.dart';   // tampilan baru khusus HP LANSIA
import '../services/fcm_service.dart';

/// Ditaruh di lib/pages/role_gate.dart
/// Menggantikan tujuan navigasi setelah SplashScreen.
/// Alur: cek status login -> cek role di Firestore -> arahkan ke
/// BottomNavigation (wali) atau ElderlyHomePage (elderly_device).
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<UserRole>(
          future: authService.getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            switch (roleSnapshot.data) {
              case UserRole.wali:
                FcmService.instance.saveWaliFcmToken();
                return const BottomNavigation();

              case UserRole.elderlyDevice:
                return const ElderlyHomePage();

              default:
                return const LoginPage();
            }
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}