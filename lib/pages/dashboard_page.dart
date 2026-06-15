import 'package:flutter/material.dart';
import 'home_page.dart';
import 'pantau_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // List of pages for the navigation shell
    final List<Widget> pages = [
      const HomePage(),
      PantauPage(onBack: () => setState(() => _currentIndex = 0)),
      const Center(child: Text('Halaman Peringatan')),
      const Center(child: Text('Halaman Profil')),
      const Center(child: Text('Halaman Pengaturan')),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Pantau'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Peringatan'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
