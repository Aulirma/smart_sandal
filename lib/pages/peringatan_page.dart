import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/backend_api_service.dart';
import '../services/firestore_monitoring_service.dart';
import 'laporan_harian_page.dart';

class PeringatanPage extends StatefulWidget {
  final VoidCallback onBackPressed;

  const PeringatanPage({
    super.key,
    required this.onBackPressed,
  });

  @override
  State<PeringatanPage> createState() => _PeringatanPageState();
}

class _PeringatanPageState extends State<PeringatanPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackendApiService _api = BackendApiService();
  final FirestoreMonitoringService _monitoringService =
      FirestoreMonitoringService.instance;

  String _emergencyName = 'Kontak wali belum tersedia';
  String _emergencyPhone = '';

  bool _isLoading = true;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _fallEventStream;
  Stream<Map<String, dynamic>?>? _telemetryStream;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Pengguna belum login.');
      }

      String? elderlyId;
      String? deviceId;
      Map<String, dynamic> profileData = {};

      // 1. Coba ambil melalui BackendApiService (seperti HomePage & PantauPage)
      try {
        final apiData = await _api.getMyElderlyProfile();
        if (apiData['exists'] == true) {
          elderlyId = apiData['elderlyId']?.toString();
          deviceId = apiData['deviceId']?.toString();
          if (apiData['profile'] is Map) {
            profileData = Map<String, dynamic>.from(apiData['profile']);
          } else {
            profileData = Map<String, dynamic>.from(apiData);
          }
        }
      } catch (e) {
        debugPrint('[PeringatanPage] Gagal ambil profil via API: $e');
      }

      // 2. Fallback: cari langsung dari Firestore elderly_profiles
      if (elderlyId == null ||
          elderlyId.isEmpty ||
          deviceId == null ||
          deviceId.isEmpty) {
        final profileQuery = await _firestore
            .collection('elderly_profiles')
            .where('waliIds', arrayContains: user.uid)
            .limit(1)
            .get();

        if (profileQuery.docs.isNotEmpty) {
          final profileDoc = profileQuery.docs.first;
          profileData = profileDoc.data();
          elderlyId ??= profileDoc.id;
          deviceId ??= profileData['deviceId']?.toString();
        }
      }

      if (elderlyId == null || elderlyId.isEmpty) {
        throw Exception('Profil lansia tidak ditemukan.');
      }

      final cleanDeviceId = (deviceId ?? '').trim();
      if (cleanDeviceId.isEmpty) {
        throw Exception('Device ID belum tersedia pada profil lansia.');
      }

      // Notifikasi untuk wali yang sedang login (tanpa orderBy di Firestore agar tidak butuh composite index)
      final notificationStream = _firestore
          .collection('notifications')
          .where('waliId', isEqualTo: user.uid)
          .snapshots();

      // Riwayat kejadian jatuh milik lansia (tanpa orderBy di Firestore agar tidak butuh composite index)
      final fallEventStream = _firestore
          .collection('fall_events')
          .where('elderlyId', isEqualTo: elderlyId)
          .snapshots();

      // Telemetry GPS terbaru dari dokumen terkini sandal pintar
      final telemetryStream =
          _monitoringService.watchLatestTelemetry(cleanDeviceId);

      if (!mounted) return;

      setState(() {
        _notificationStream = notificationStream;
        _fallEventStream = fallEventStream;
        _telemetryStream = telemetryStream;
        _isLoading = false;
      });

      await _loadEmergencyContact(
        profileData: profileData,
        currentUid: user.uid,
        elderlyId: elderlyId,
      );
    } catch (e) {
      debugPrint(
          '[PeringatanPage] Gagal menginisialisasi halaman peringatan: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mengambil kontak darurat dari data wali pada koleksi users.
  Future<void> _loadEmergencyContact({
    required Map<String, dynamic> profileData,
    required String currentUid,
    required String elderlyId,
  }) async {
    try {
      List<String> waliIds = List<String>.from(profileData['waliIds'] ?? []);

      if (waliIds.isEmpty) {
        final doc =
            await _firestore.collection('elderly_profiles').doc(elderlyId).get();
        if (doc.exists) {
          waliIds = List<String>.from(doc.data()?['waliIds'] ?? []);
        }
      }

      if (waliIds.isEmpty) return;

      // Prioritaskan wali lain selain pengguna yang sedang login.
      final otherWaliIds = waliIds.where((id) => id != currentUid).toList();

      final targetWaliId =
          otherWaliIds.isNotEmpty ? otherWaliIds.first : waliIds.first;

      final waliDoc =
          await _firestore.collection('users').doc(targetWaliId).get();

      if (!waliDoc.exists) return;

      final waliData = waliDoc.data()!;

      if (!mounted) return;

      setState(() {
        _emergencyName = waliData['name']?.toString() ?? 'Wali';
        _emergencyPhone = waliData['phone']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('[PeringatanPage] Gagal mengambil kontak darurat: $e');
    }
  }

  // Menghubungi nomor wali yang diambil dari Firestore.
  Future<void> _makeEmergencyCall() async {
    if (_emergencyPhone.trim().isEmpty) {
      _showMessage('Nomor telepon kontak wali belum tersedia.');
      return;
    }

    final phone = _emergencyPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: phone);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage('Tidak dapat membuka aplikasi telepon.');
      }
    } catch (e) {
      _showMessage('Gagal membuka aplikasi telepon.');
    }
  }

  // Tandai satu notifikasi sebagai sudah dibaca di Firestore.
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      _showMessage('Gagal memperbarui status notifikasi.');
    }
  }

  // Tandai semua notifikasi milik wali sebagai sudah dibaca.
  Future<void> _markAllAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      final unreadDocs = docs.where(
        (doc) => doc.data()['read'] != true,
      );

      final batch = _firestore.batch();

      for (final doc in unreadDocs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();

      _showMessage('Semua notifikasi telah dibaca.');
    } catch (e) {
      _showMessage('Gagal menandai notifikasi.');
    }
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Tidak dapat membuka Google Maps.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatTime(dynamic value) {
    final date = _parseDateTime(value);
    if (date == null) return 'Waktu tidak tersedia';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${date.day}/${date.month}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
  }

  String _notificationTitle(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'fall_alert':
        return 'Peringatan Risiko Jatuh';
      case 'low_battery':
        return 'Baterai Rendah';
      case 'unstable_activity':
        return 'Langkah Tidak Stabil';
      case 'daily_report':
        return 'Laporan Harian Siap';
      default:
        return 'Notifikasi';
    }
  }

  IconData _notificationIcon(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'fall_alert':
        return Icons.shield_outlined;
      case 'low_battery':
        return Icons.battery_alert;
      case 'unstable_activity':
        return Icons.warning_amber_rounded;
      case 'daily_report':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _notificationColor(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'fall_alert':
        return Colors.red;
      case 'low_battery':
      case 'unstable_activity':
        return Colors.orange;
      case 'daily_report':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_notificationStream == null ||
        _fallEventStream == null ||
        _telemetryStream == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBackPressed,
          ),
          title: const Text('Peringatan'),
        ),
        body: const Center(
          child: Text('Data profil lansia tidak dapat dimuat.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          'Peringatan',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              return TextButton(
                onPressed: docs.isEmpty ? null : () => _markAllAsRead(docs),
                child: const Text(
                  'Tandai semua dibaca',
                  style: TextStyle(
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fallEventStream,
        builder: (context, fallSnapshot) {
          final rawFallDocs = fallSnapshot.data?.docs ?? [];
          final fallDocs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(rawFallDocs);

          // Urutkan kejadian jatuh terbaru di atas (client-side)
          fallDocs.sort((a, b) {
            final ta = _parseDateTime(a.data()['timestamp']);
            final tb = _parseDateTime(b.data()['timestamp']);
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

          final activeFall = fallDocs.where(
            (doc) => doc.data()['acknowledged'] != true,
          ).toList();

          final latestFall =
              fallDocs.isNotEmpty ? fallDocs.first.data() : null;

          return StreamBuilder<Map<String, dynamic>?>(
            stream: _telemetryStream,
            builder: (context, telemetrySnapshot) {
              final telemetry = telemetrySnapshot.data;
              final gps = telemetry?['gps'];
              double? latitude;
              double? longitude;

              if (gps is Map) {
                final rawLat = gps['latitude'];
                final rawLng = gps['longitude'];
                if (rawLat is num) latitude = rawLat.toDouble();
                if (rawLng is num) longitude = rawLng.toDouble();
              }

              dynamic gpsTime = telemetry?['lastSeen'];

              // Jika GPS reading belum tersedia di telemetry, gunakan lokasi event jatuh terakhir.
              if ((latitude == null || longitude == null) && latestFall != null) {
                if (latestFall['location'] is GeoPoint) {
                  final location = latestFall['location'] as GeoPoint;
                  latitude = location.latitude;
                  longitude = location.longitude;
                } else if (latestFall['latitude'] is num &&
                    latestFall['longitude'] is num) {
                  latitude = (latestFall['latitude'] as num).toDouble();
                  longitude = (latestFall['longitude'] as num).toDouble();
                }
                gpsTime ??= latestFall['timestamp'];
              }

              final bool hasLocation = latitude != null &&
                  longitude != null &&
                  latitude >= -90 &&
                  latitude <= 90 &&
                  longitude >= -180 &&
                  longitude <= 180;

              final DateTime? lastSeen = _parseDateTime(gpsTime);
              final bool isDeviceOnline = lastSeen != null &&
                  DateTime.now().difference(lastSeen) <=
                      const Duration(minutes: 2);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUrgentCard(
                      hasActiveFall: activeFall.isNotEmpty,
                      hasLocation: hasLocation,
                      latitude: latitude,
                      longitude: longitude,
                      gpsTime: gpsTime,
                      isDeviceOnline: isDeviceOnline,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Riwayat Peringatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _notificationStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint(
                              '[PeringatanPage] Gagal memuat notifikasi: ${snapshot.error}');
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade400, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Gagal memuat notifikasi.',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final rawDocs = snapshot.data?.docs ?? [];
                        final docs =
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                          rawDocs,
                        );

                        // Urutkan notifikasi terbaru di atas (client-side)
                        docs.sort((a, b) {
                          final ta = _parseDateTime(a.data()['createdAt']);
                          final tb = _parseDateTime(b.data()['createdAt']);
                          if (ta == null && tb == null) return 0;
                          if (ta == null) return 1;
                          if (tb == null) return -1;
                          return tb.compareTo(ta);
                        });

                        if (docs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Belum ada riwayat peringatan.'),
                            ),
                          );
                        }

                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildNotificationItem(
                                doc.id,
                                data,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUrgentCard({
    required bool hasActiveFall,
    required bool hasLocation,
    required double? latitude,
    required double? longitude,
    required dynamic gpsTime,
    required bool isDeviceOnline,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasActiveFall
            ? const Color(0xFFFFEBEE)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveFall
              ? Colors.red.shade200
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasActiveFall
                    ? Icons.shield_outlined
                    : Icons.health_and_safety_outlined,
                color: hasActiveFall ? Colors.red : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveFall
                          ? 'Peringatan Risiko Jatuh'
                          : 'Status Darurat',
                      style: TextStyle(
                        color: hasActiveFall
                            ? Colors.red.shade900
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      hasActiveFall
                          ? 'Terdapat kejadian jatuh yang belum ditangani.'
                          : 'Tidak ada kejadian jatuh yang belum ditangani.',
                      style: TextStyle(
                        color: hasActiveFall
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lokasi GPS Terakhir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDeviceOnline && hasLocation
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isDeviceOnline && hasLocation
                            ? 'GPS AKTIF'
                            : 'GPS OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDeviceOnline && hasLocation
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: hasLocation
                        ? FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(latitude!, longitude!),
                              initialZoom: 16,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.smart_sandal',
                                tileProvider: NetworkTileProvider(
                                  cachingProvider:
                                      DisabledMapCachingProvider(),
                                ),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(latitude, longitude),
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off,
                                      size: 38, color: Colors.grey),
                                  SizedBox(height: 6),
                                  Text(
                                    'Lokasi GPS belum tersedia.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasLocation
                      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                      : 'Lokasi GPS belum tersedia.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diperbarui: ${_formatTime(gpsTime)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () => _openMap(latitude!, longitude!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Buka di Google Maps'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kontak Darurat: $_emergencyName',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            _emergencyPhone.isEmpty
                ? 'Nomor telepon belum tersedia'
                : _emergencyPhone,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed:
                  _emergencyPhone.isEmpty ? null : _makeEmergencyCall,
              icon: const Icon(Icons.call, color: Colors.white),
              label: const Text(
                'Hubungi Kontak Darurat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                disabledBackgroundColor: Colors.grey,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    String notificationId,
    Map<String, dynamic> data,
  ) {
    final isRead = data['read'] == true;
    final color = _notificationColor(data);

    final title = _notificationTitle(data);
    final message = data['message']?.toString() ?? '';
    final time = _formatTime(data['createdAt']);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!isRead) {
            await _markAsRead(notificationId);
          }

          if (data['type'] == 'daily_report' && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LaporanHarianPage(),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead
                ? Theme.of(context).cardColor
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E3A47)
                    : const Color(0xFFF0F9FF)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _notificationIcon(data),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!isRead)
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: Colors.red,
                          ),
                        if (isRead)
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 17,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRead ? 'Sudah dibaca' : 'Belum dibaca',
                      style: TextStyle(
                        fontSize: 11,
                        color: isRead ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
