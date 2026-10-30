import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/backend_api_service.dart';
import '../services/firestore_monitoring_service.dart';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onNotificationPressed;
  final VoidCallback onAddElderlyPressed;

  const HomePage({
    super.key,
    required this.onNotificationPressed,
    required this.onAddElderlyPressed,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BackendApiService _api = BackendApiService();
  final FirestoreMonitoringService _monitoringService =
      FirestoreMonitoringService.instance;

  String? _getTinyMLActivity(Map<String, dynamic>? telemetry) {
    if (telemetry == null) return null;
    final tinyml = telemetry['tinyml'];
    if (tinyml is! Map) return null;
    final activity = tinyml['activity'];
    if (activity is! String) return null;
    return activity.trim();
  }

  bool _isFallActivity(String? activity) {
    return activity == 'jatuh_debel' || activity == 'jatuh_samping';
  }

  void _checkForFall(Map<String, dynamic>? telemetry) {
    final activity = _getTinyMLActivity(telemetry);
    if (activity == null) return;

    debugPrint('[HomePage] TinyML activity: $activity');
    final isFall = _isFallActivity(activity);

    if (!isFall) {
      _lastTinyMLActivity = activity;
      return;
    }

    if (_fallEventProcessing) return;
    if (_isSameFallActivity(activity)) return;
    if (_isFallCooldownActive()) {
      debugPrint('[HomePage] Fall alert masih dalam cooldown.');
      return;
    }

    debugPrint('[HomePage] FALL TERDETEKSI: $activity');
    _lastTinyMLActivity = activity;
    _lastFallDetectedAt = DateTime.now();
    _sendFallEvent(telemetry);
  }

  bool _isSameFallActivity(String activity) {
    return _isFallActivity(_lastTinyMLActivity) &&
        _lastTinyMLActivity == activity;
  }

  bool _isFallCooldownActive() {
    if (_lastFallDetectedAt == null) return false;
    final elapsed = DateTime.now().difference(_lastFallDetectedAt!);
    return elapsed < _fallAlertCooldown;
  }

  Future<void> _sendFallEvent(Map<String, dynamic>? telemetry) async {
    if (telemetry == null ||
        _elderlyId == null ||
        _elderlyId!.isEmpty ||
        _deviceId == null ||
        _deviceId!.isEmpty) {
      debugPrint('[HomePage] Fall event dibatalkan: Data tidak lengkap.');
      return;
    }

    _fallEventProcessing = true;

    try {
      final gps = telemetry['gps'];
      double? latitude;
      double? longitude;

      if (gps is Map) {
        final rawLatitude = gps['latitude'];
        final rawLongitude = gps['longitude'];
        if (rawLatitude is num) latitude = rawLatitude.toDouble();
        if (rawLongitude is num) longitude = rawLongitude.toDouble();
      }

      await _api.sendFallEvent(
        severity: 'high',
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint('[HomePage] FALL EVENT BERHASIL DIKIRIM KE BACKEND');
    } catch (e) {
      debugPrint('[HomePage] GAGAL MENGIRIM FALL EVENT: $e');
    } finally {
      _fallEventProcessing = false;
    }
  }

  bool _isLoading = true;
  bool _hasElderly = false;

  String? _elderlyId;
  String? _elderlyName;
  int? _elderlyAge;
  String? _deviceId;
  Map<String, dynamic>? _latestTelemetry;
  String? _lastTinyMLActivity;
  bool _fallEventProcessing = false;

  DateTime? _lastFallDetectedAt;
  static const Duration _fallAlertCooldown = Duration(seconds: 30);

  StreamSubscription? _profileSubscription;
  StreamSubscription? _telemetrySubscription;

  static const Duration _deviceOfflineThreshold = Duration(minutes: 2);

  DateTime? _parseLastSeen(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return 'Belum tersedia';
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) return 'beberapa detik lalu';
    if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
    if (difference.inHours < 24) return '${difference.inHours} jam lalu';
    if (difference.inDays < 30) return '${difference.inDays} hari lalu';
    return 'lebih dari 30 hari lalu';
  }

  bool get _isDeviceConnected {
    if (_deviceId == null || _deviceId!.isEmpty) return false;
    final lastSeen = _parseLastSeen(_latestTelemetry?['lastSeen']);
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) <= _deviceOfflineThreshold;
  }

  @override
  void initState() {
    super.initState();
    _loadElderlyProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFIL DARI BACKEND
  // ============================================================

  Future<void> _loadElderlyProfile() async {
    try {
      final data = await _api.getMyElderlyProfile();

      if (!mounted) return;

      if (data != null && data is Map && data['exists'] == true) {
        final elderlyId = data['elderlyId']?.toString();

        setState(() {
          _hasElderly = true;
          _elderlyId = elderlyId;
          _elderlyName = data['name']?.toString();
          _elderlyAge = _parseAge(data['age']);
          _deviceId = _cleanDeviceId(data['deviceId']);
        });

        if (elderlyId != null && elderlyId.isNotEmpty) {
          _listenToElderlyProfile(elderlyId);
        }
      } else {
        _clearElderlyData();
      }
    } catch (e) {
      debugPrint('[HomePage] Gagal mengambil profil: $e');
      if (!mounted) return;
      _clearElderlyData();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FIRESTORE REALTIME
  // ============================================================

  void _listenToElderlyProfile(String elderlyId) {
    _profileSubscription?.cancel();

    debugPrint('[HomePage] Listening elderly_profiles/$elderlyId');

    _profileSubscription = FirebaseFirestore.instance
        .collection('elderly_profiles')
        .doc(elderlyId)
        .snapshots()
        .listen(
          (snapshot) {
        if (!snapshot.exists) {
          _telemetrySubscription?.cancel();
          _telemetrySubscription = null;

          if (!mounted) return;

          setState(() {
            _hasElderly = false;
            _elderlyId = null;
            _elderlyName = null;
            _elderlyAge = null;
            _deviceId = null;
            _latestTelemetry = null;
          });
          return;
        }

        final data = snapshot.data();
        if (data == null) return;

        final deviceId = _cleanDeviceId(data['deviceId']);

        if (!mounted) return;

        final deviceChanged = _deviceId != deviceId;

        setState(() {
          _hasElderly = true;
          _elderlyId = snapshot.id;
          _elderlyName = data['name']?.toString();
          _elderlyAge = _parseAge(data['age']);
          _deviceId = deviceId;
        });

        if (deviceChanged || _telemetrySubscription == null) {
          if (deviceId != null && deviceId.isNotEmpty) {
            _listenToLatestTelemetry(deviceId);
          } else {
            _telemetrySubscription?.cancel();
            _telemetrySubscription = null;
            setState(() {
              _latestTelemetry = null;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('[HomePage] Firestore listener error: $error');
      },
    );
  }

  // ============================================================
  // FIRESTORE REALTIME TELEMETRY
  // ============================================================

  void _listenToLatestTelemetry(String deviceId) {
    _telemetrySubscription?.cancel();

    final cleanDeviceId = deviceId.trim();

    if (cleanDeviceId.isEmpty) {
      if (mounted) {
        setState(() {
          _latestTelemetry = null;
        });
      }
      return;
    }

    _telemetrySubscription = _monitoringService
        .watchLatestTelemetry(cleanDeviceId)
        .listen(
          (data) {
        if (!mounted) return;

        if (data == null) {
          setState(() {
            _latestTelemetry = null;
          });
          return;
        }

        _checkForFall(data);

        setState(() {
          _latestTelemetry = Map<String, dynamic>.from(data);
        });
      },
      onError: (error) {
        debugPrint('[HomePage] Telemetry listener error: $error');
      },
    );
  }

  void _clearElderlyData() {
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;

    setState(() {
      _hasElderly = false;
      _elderlyId = null;
      _elderlyName = null;
      _elderlyAge = null;
      _deviceId = null;
      _latestTelemetry = null;
    });
  }

  int? _parseAge(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String? _cleanDeviceId(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    if (result.isEmpty || result == 'null') return null;
    return result;
  }

  String _getWaliName() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final name = email.split('@').first;
      if (name.isNotEmpty) return name;
    }
    return 'Wali';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard(context), // SELALU RENDER DASHBOARD UTAMA
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadElderlyProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLiveLocation(context),
                  const SizedBox(height: 24),
                  _buildMetricsRow(context),
                  const SizedBox(height: 24),
                  Text(
                    'Aktivitas Hari Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActivityTimeline(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D9488),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat Datang 👋',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dasbor ${_getWaliName()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onNotificationPressed,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildElderlySummaryCard(context),
        ],
      ),
    );
  }

  // ============================================================
  // ELDERLY SUMMARY CARD
  // ============================================================

  Widget _buildElderlySummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _hasElderly
          ? _buildElderlyInfo(context)
          : _buildAddElderlyContent(context),
    );
  }

  Widget _buildElderlyInfo(BuildContext context) {
    final lastSeen = _parseLastSeen(_latestTelemetry?['lastSeen']);
    final tinyml = _latestTelemetry?['tinyml'];

    String stabilityText = 'Belum tersedia';
    String fallRiskText = 'Belum tersedia';

    if (tinyml is Map) {
      if (tinyml['stability'] != null) {
        stabilityText = tinyml['stability'].toString();
      }
      if (tinyml['fallRisk'] != null) {
        fallRiskText = tinyml['fallRisk'].toString();
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _elderlyName ?? 'Lansia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (_elderlyAge != null)
                    Text(
                      'Usia $_elderlyAge tahun',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Terakhir aktif: ${_formatTimeAgo(lastSeen)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _buildDeviceStatusBadge(context),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildStatusSubCard(
              icon: Icons.directions_walk,
              label: 'Stabilitas Langkah',
              value: stabilityText,
              color: const Color(0xFF0D9488),
            ),
            const SizedBox(width: 12),
            _buildStatusSubCard(
              icon: Icons.warning_amber_rounded,
              label: 'Risiko Jatuh',
              value: fallRiskText,
              color: const Color(0xFF0D9488),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddElderlyContent(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Icon(
          Icons.person_add_alt_1,
          size: 42,
          color: const Color(0xFF0D9488).withValues(alpha: 0.8),
        ),
        const SizedBox(height: 12),
        Text(
          'Belum Ada Profil Lansia',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tambahkan profil lansia untuk mulai menggunakan EMERYS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onAddElderlyPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '+ Tambah Profil Lansia',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _deviceStatusText {
    if (_deviceId == null || _deviceId!.isEmpty) return 'Belum Terhubung';
    final lastSeen = _parseLastSeen(_latestTelemetry?['lastSeen']);
    if (lastSeen == null) return 'Menunggu Data';
    return DateTime.now().difference(lastSeen) <= _deviceOfflineThreshold
        ? 'Aktif'
        : 'Offline';
  }

  Widget _buildDeviceStatusBadge(BuildContext context) {
    final status = _deviceStatusText;
    final Color dotColor;
    final Color backgroundColor;
    final Color textColor;

    if (status == 'Aktif') {
      dotColor = const Color(0xFF2DD4BF);
      backgroundColor = AppTheme.primaryColor.withValues(alpha: 0.15);
      textColor = const Color(0xFF0D9488);
    } else if (status == 'Offline') {
      dotColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.10);
      textColor = Colors.red;
    } else {
      dotColor = Colors.orange;
      backgroundColor = Colors.orange.withValues(alpha: 0.12);
      textColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS SUB CARD
  // ============================================================

  Widget _buildStatusSubCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  Widget _buildLiveLocation(BuildContext context) {
    final gps = _latestTelemetry?['gps'];
    double? latitude;
    double? longitude;

    if (gps is Map) {
      final rawLatitude = gps['latitude'];
      final rawLongitude = gps['longitude'];
      if (rawLatitude is num) latitude = rawLatitude.toDouble();
      if (rawLongitude is num) longitude = rawLongitude.toDouble();
    }

    final bool hasLocation = latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;

    final bool isDeviceOnline = _deviceStatusText == 'Aktif';
    final DateTime? lastSeen = _parseLastSeen(_latestTelemetry?['lastSeen']);
    final LatLng? elderlyLocation =
    hasLocation ? LatLng(latitude, longitude) : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Lokasi Langsung',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDeviceOnline && hasLocation
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDeviceOnline && hasLocation ? 'GPS AKTIF' : 'GPS OFFLINE',
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
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: hasLocation
                  ? FlutterMap(
                options: MapOptions(
                  initialCenter: elderlyLocation!,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.smart_sandal',
                    tileProvider: NetworkTileProvider(
                      cachingProvider: DisabledMapCachingProvider(),
                    ),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: elderlyLocation,
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
                          size: 42, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Lokasi belum tersedia',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _elderlyName ?? 'Lansia',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasLocation)
                      Text(
                        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                if (hasLocation && lastSeen != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Lokasi terakhir diperbarui ${_formatTimeAgo(lastSeen)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METRICS
  // ============================================================

  Widget _buildMetricsRow(BuildContext context) {
    final battery = _latestTelemetry?['battery'];
    final String batteryText = battery != null ? '$battery%' : 'Belum tersedia';

    return Row(
      children: [
        _buildMetricCard(
          context,
          icon: Icons.stacked_line_chart,
          value: 'Belum tersedia',
          label: 'Langkah Hari Ini',
          color: const Color(0xFF0D9488),
        ),
        const SizedBox(width: 12),
        _buildMetricCard(
          context,
          icon: Icons.battery_charging_full,
          value: batteryText,
          label: 'Baterai Sandal',
          color: const Color(0xFF0D9488),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
        required Color color,
      }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTIVITY TIMELINE
  // ============================================================

  Widget _buildActivityTimeline(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Tersedia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aktivitas harian akan tampil secara otomatis setelah sandal EMERYS mengirimkan data monitoring.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// GRID PAINTER
// ================================================================

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (double i = 0; i <= size.width; i += 40) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    for (double i = 0; i <= size.height; i += 40) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}