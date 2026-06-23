import 'package:flutter/material.dart';
import 'home_page.dart';
import 'pantau_page.dart';
import 'peringatan_page.dart';
import 'profil_page.dart';
import 'pengaturan_page.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // List of pages for the navigation shell
    final List<Widget> pages = [
      HomePage(onNotificationPressed: () => setState(() => _currentIndex = 2)),
      PantauPage(onBackPressed: () => setState(() => _currentIndex = 0)),
      PeringatanPage(onBackPressed: () => setState(() => _currentIndex = 0)),
      ProfilPage(onBackPressed: () => setState(() => _currentIndex = 0)),
      PengaturanPage(onBackPressed: () => setState(() => _currentIndex = 0)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D9488),
        unselectedItemColor: Colors.grey[400],
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
