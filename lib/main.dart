import 'package:flutter/material.dart';
import 'pages/splash_screen.dart';
// import 'pages/cobatok.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';


void main() {
  runApp(const MyApp());
}

final ThemeController themeController = ThemeController();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp(
          title: 'EMERYS Smart Sandal',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController.themeMode,

          home: const SplashScreen(),
        );
      },
    );
  }
}
