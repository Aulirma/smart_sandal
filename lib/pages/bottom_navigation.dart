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

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:smart_sandal/services/backend_api_service.dart';
//
// import 'home_page.dart';
// import 'pantau_page.dart';
// import 'peringatan_page.dart';
// import 'profil_page.dart';
// import 'pengaturan_page.dart';
// import '../theme/app_theme.dart';
//
// class BottomNavigation extends StatefulWidget {
//   const BottomNavigation({super.key});
//
//   @override
//   State<BottomNavigation> createState() => _BottomNavigationState();
// }
//
// class _BottomNavigationState extends State<BottomNavigation> {
//   int _currentIndex = 0;
//
//   /// Jumlah peringatan yang belum dibaca (real time dari Firestore).
//   /// Null selama profil/perangkat belum berhasil dimuat.
//   Stream<int>? _unreadStream;
//
//   @override
//   void initState() {
//     super.initState();
//     _initUnreadBadge();
//   }
//
//   Future<void> _initUnreadBadge() async {
//     try {
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid == null) return;
//
//       final raw = await BackendApiService().getMyElderlyProfile();
//       final profile = raw['profile'] is Map
//           ? Map<String, dynamic>.from(raw['profile'])
//           : raw;
//       final deviceId =
//       (profile['deviceId'] ?? profile['device_id'] ?? '').toString().trim();
//       if (deviceId.isEmpty || !mounted) return;
//
//       final stream = FirebaseFirestore.instance
//           .collection('device_telemetry')
//           .doc(deviceId)
//           .collection(kAlertsSubcollection)
//           .orderBy('createdAt', descending: true)
//           .limit(50)
//           .snapshots()
//           .map((snap) => snap.docs.where((d) {
//         final readBy = (d.data()['readBy'] as List?)
//             ?.map((e) => e.toString())
//             .toList() ??
//             const <String>[];
//         return !readBy.contains(uid);
//       }).length);
//
//       if (!mounted) return;
//       setState(() => _unreadStream = stream);
//     } catch (_) {
//       // Badge hanya pelengkap; kalau gagal, tampilkan ikon biasa.
//     }
//   }
//
//   Widget _alertIcon() {
//     const icon = Icon(Icons.notifications_outlined);
//     final stream = _unreadStream;
//     if (stream == null) return icon;
//
//     return StreamBuilder<int>(
//       stream: stream,
//       builder: (context, snap) {
//         final count = snap.data ?? 0;
//         return Badge(
//           isLabelVisible: count > 0,
//           label: Text(count > 99 ? '99+' : '$count'),
//           child: icon,
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final List<Widget> pages = [
//       HomePage(
//         onNotificationPressed: () => setState(() => _currentIndex = 2),
//         onAddElderlyPressed: () => setState(() => _currentIndex = 3),
//       ),
//       PantauPage(
//         onBackPressed: () => setState(() => _currentIndex = 0),
//       ),
//       PeringatanPage(
//         onBackPressed: () => setState(() => _currentIndex = 0),
//       ),
//       ProfilPage(
//         onBackPressed: () => setState(() => _currentIndex = 0),
//       ),
//       PengaturanPage(
//         onBackPressed: () => setState(() => _currentIndex = 0),
//       ),
//     ];
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       body: pages[_currentIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: AppTheme.primaryColor,
//         unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
//         currentIndex: _currentIndex,
//         onTap: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         showSelectedLabels: true,
//         showUnselectedLabels: true,
//         selectedLabelStyle:
//         const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//         unselectedLabelStyle: const TextStyle(fontSize: 10),
//         items: [
//           const BottomNavigationBarItem(
//               icon: Icon(Icons.home_outlined), label: 'Beranda'),
//           const BottomNavigationBarItem(
//               icon: Icon(Icons.monitor_heart_outlined), label: 'Pantau'),
//           BottomNavigationBarItem(
//             icon: _alertIcon(),
//             label: 'Peringatan',
//           ),
//           const BottomNavigationBarItem(
//               icon: Icon(Icons.person_outline), label: 'Profil'),
//           const BottomNavigationBarItem(
//               icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
//         ],
//       ),
//     );
//   }
// }
