import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Stream<int>? _unreadStream;

  @override
  void initState() {
    super.initState();
    _listenToUnreadNotifications();
  }

  void _listenToUnreadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _unreadStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('waliId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) => doc.data()['read'] != true).length;
    });
  }

  Widget _buildAlertIcon() {
    const defaultIcon = Icon(Icons.notifications_outlined);
    final stream = _unreadStream;
    if (stream == null) return defaultIcon;

    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        if (unreadCount <= 0) {
          return defaultIcon;
        }
        return Badge(
          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
          child: defaultIcon,
        );
      },
    );
  }

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
        selectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Pantau',
          ),
          BottomNavigationBarItem(
            icon: _buildAlertIcon(),
            label: 'Peringatan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
