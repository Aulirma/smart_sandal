import 'package:flutter/material.dart';
import 'home_page.dart';
import 'pantau_page.dart';
import 'peringatan_page.dart';
import 'profil_page.dart';
import 'pengaturan_page.dart';
import '../theme/app_theme.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(
        onNotificationPressed: () =>
            setState(() => _currentIndex = 2),
        onAddElderlyPressed: () =>
            setState(() => _currentIndex = 3),
      ),
      PantauPage(
        onBackPressed: () =>
            setState(() => _currentIndex = 0),
      ),
      PeringatanPage(
        onBackPressed: () =>
            setState(() => _currentIndex = 0),
      ),
      ProfilPage(
        onBackPressed: () =>
            setState(() => _currentIndex = 0),
      ),
      PengaturanPage(
        onBackPressed: () =>
            setState(() => _currentIndex = 0),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          const BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Pantau'),
          BottomNavigationBarItem(
            icon: Badge(
              label: const Text('3'),
              child: const Icon(Icons.notifications_outlined),
            ),
            label: 'Peringatan',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
