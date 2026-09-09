import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String? _getTinyMLActivity(
      Map<String, dynamic>? telemetry,
      ) {
    if (telemetry == null) {
      return null;
    }
    final tinyml = telemetry['tinyml'];
    if (tinyml is! Map) {
      return null;
    }
    final activity = tinyml['activity'];
    if (activity is! String) {
      return null;
    }
    return activity.trim();
  }

  bool _isFallActivity(String? activity) {
    return activity == 'jatuh_debel' ||
        activity == 'jatuh_samping';
  }

  void _checkForFall(
      Map<String, dynamic>? telemetry,
      ) {
    final activity = _getTinyMLActivity(telemetry);
    if (activity == null) {
      return;
    }
    debugPrint(
      '[HomePage] TinyML activity: $activity',
    );
    final isFall = _isFallActivity(activity);
    // Simpan activity terakhir
    if (!isFall) {
      _lastTinyMLActivity = activity;
      return;
    }
    // Jangan proses kalau sedang mengirim event
    if (_fallEventProcessing) {
      return;
    }
    // Cegah satu kondisi jatuh dikirim berkali-kali
    if (_isSameFallActivity(activity)) {
      return;
    }
    // Cooldown
    if (_isFallCooldownActive()) {
      debugPrint(
        '[HomePage] Fall alert masih dalam cooldown.',
      );
      return;
    }
    debugPrint(
      '[HomePage] FALL TERDETEKSI: $activity',
    );
    _lastTinyMLActivity = activity;
    _lastFallDetectedAt = DateTime.now();
    _sendFallEvent(telemetry);
  }

  bool _isSameFallActivity(String activity) {
    return _isFallActivity(_lastTinyMLActivity) &&
        _lastTinyMLActivity == activity;
  }

  bool _isFallCooldownActive() {
    if (_lastFallDetectedAt == null) {
      return false;
    }

    final elapsed =
    DateTime.now().difference(_lastFallDetectedAt!);

    return elapsed < _fallAlertCooldown;
  }

  Future<void> _sendFallEvent(
      Map<String, dynamic>? telemetry,
      ) async {
    if (telemetry == null) {
      debugPrint(
        '[HomePage] Fall event dibatalkan: telemetry null.',
      );
      return;
    }

    if (_elderlyId == null ||
        _elderlyId!.isEmpty) {
      debugPrint(
        '[HomePage] Fall event dibatalkan: elderlyId tidak tersedia.',
      );
      return;
    }

    if (_deviceId == null ||
        _deviceId!.isEmpty) {
      debugPrint(
        '[HomePage] Fall event dibatalkan: deviceId tidak tersedia.',
      );
      return;
    }

    _fallEventProcessing = true;

    try {
      final tinyml = telemetry['tinyml'];

      String? activity;
      double? confidence;

      if (tinyml is Map) {
        final rawActivity = tinyml['activity'];

        if (rawActivity is String) {
          activity = rawActivity.trim();
        }

        final rawConfidence = tinyml['confidence'];

        if (rawConfidence is num) {
          confidence = rawConfidence.toDouble();
        }
      }

      debugPrint(
        '[HomePage] Mengirim FALL EVENT',
      );

      debugPrint(
        'activity: $activity',
      );

      debugPrint(
        'confidence: $confidence',
      );

      debugPrint(
        'deviceId: $_deviceId',
      );

      debugPrint(
        'elderlyId: $_elderlyId',
      );

      final gps = telemetry['gps'];

      double? latitude;
      double? longitude;

      if (gps is Map) {
        final rawLatitude = gps['latitude'];
        final rawLongitude = gps['longitude'];

        if (rawLatitude is num) {
          latitude = rawLatitude.toDouble();
        }

        if (rawLongitude is num) {
          longitude = rawLongitude.toDouble();
        }
      }

      await _api.sendFallEvent(
        severity: 'high',
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint(
        '[HomePage] FALL EVENT BERHASIL DIKIRIM',
      );
    } catch (e) {
      debugPrint(
        '[HomePage] GAGAL MENGIRIM FALL EVENT: $e',
      );
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

  static const Duration _fallAlertCooldown =
  Duration(seconds: 30);

  StreamSubscription<
      DocumentSnapshot<Map<String, dynamic>>>? _profileSubscription;

  StreamSubscription<Map<String, dynamic>?>?
    _telemetrySubscription;

  static const Duration _deviceOfflineThreshold =
    Duration(minutes: 2);

  DateTime? _parseLastSeen(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  bool get _isDeviceConnected {
    if (_deviceId == null || _deviceId!.isEmpty) {
      return false;
    }

    final lastSeen = _parseLastSeen(
      _latestTelemetry?['lastSeen'],
    );

    if (lastSeen == null) {
      return false;
    }

    final difference =
    DateTime.now().difference(lastSeen);

    return difference <= _deviceOfflineThreshold;
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

      if (data['exists'] == true) {
        final elderlyId =
        data['elderlyId']?.toString();

        setState(() {
          _hasElderly = true;
          _elderlyId = elderlyId;
          _elderlyName =
              data['name']?.toString();
          _elderlyAge =
              _parseAge(data['age']);
          _deviceId =
              _cleanDeviceId(data['deviceId']);
        });

        if (elderlyId != null &&
            elderlyId.isNotEmpty) {
          _listenToElderlyProfile(
            elderlyId,
          );
        }
      } else {
        _clearElderlyData();
      }
    } catch (e) {
      debugPrint(
        '[HomePage] Gagal mengambil profil: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil data lansia: $e',
          ),
        ),
      );
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

  void _listenToElderlyProfile(
      String elderlyId,
      ) {
    _profileSubscription?.cancel();

    debugPrint(
      '[HomePage] Listening elderly_profiles/$elderlyId',
    );

    _profileSubscription = FirebaseFirestore
        .instance
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

        final deviceId =
        _cleanDeviceId(data['deviceId']);

        debugPrint(
          '[HomePage] Firestore update '
              'deviceId=$deviceId',
        );

        if (!mounted) return;

        final deviceChanged =
            _deviceId != deviceId;

        setState(() {
          _hasElderly = true;
          _elderlyId = snapshot.id;
          _elderlyName =
              data['name']?.toString();
          _elderlyAge =
              _parseAge(data['age']);
          _deviceId = deviceId;
        });

        if (deviceChanged) {
          if (deviceId != null &&
              deviceId.isNotEmpty) {

            _listenToLatestTelemetry(
              deviceId,
            );

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
        debugPrint(
          '[HomePage] Firestore listener error: $error',
        );
      },
    );
  }

  // ============================================================
// FIRESTORE REALTIME TELEMETRY
// ============================================================

  void _listenToLatestTelemetry(
      String deviceId,
      ) {
    _telemetrySubscription?.cancel();

    final cleanDeviceId = deviceId.trim();

    if (cleanDeviceId.isEmpty) {
      debugPrint(
        '[HomePage] Tidak ada deviceId untuk monitoring.',
      );

      if (mounted) {
        setState(() {
          _latestTelemetry = null;
        });
      }

      return;
    }

    debugPrint(
      '[HomePage] Listening latest telemetry: '
          'device_telemetry/$cleanDeviceId/latest/current',
    );

    _telemetrySubscription =
        _monitoringService
            .watchLatestTelemetry(cleanDeviceId)
            .listen(
              (data) {
            if (!mounted) return;

            if (data == null) {
              debugPrint('[HomePage] latest/current belum tersedia.');

              setState(() {
                _latestTelemetry = null;
              });

              return;
            }

            debugPrint('[HomePage] TELEMETRY UPDATE');
            debugPrint('deviceId: ${data['deviceId']}');
            debugPrint('sequence: ${data['sequence']}');
            debugPrint('status: ${data['status']}');
            debugPrint('lastSeen: ${data['lastSeen']}');

            // Cek TinyML
            _checkForFall(data);

            setState(() {
              _latestTelemetry =
              Map<String, dynamic>.from(data);
            });

            debugPrint(
              '[HomePage] TELEMETRY UPDATE',
            );

            debugPrint(
              'deviceId: ${data['deviceId']}',
            );

            debugPrint(
              'sequence: ${data['sequence']}',
            );

            debugPrint(
              'status: ${data['status']}',
            );

            debugPrint(
              'lastSeen: ${data['lastSeen']}',
            );

            final lastSeen = _parseLastSeen(
              data['lastSeen'],
            );

            if (lastSeen != null) {
              final age =
              DateTime.now().difference(lastSeen);

              debugPrint(
                'lastSeen age: ${age.inSeconds} detik',
              );

              debugPrint(
                'HomePage status: '
                    '${age <= _deviceOfflineThreshold ? 'Aktif' : 'Offline'}',
              );
            }

            debugPrint(
              'deviceId: ${data['deviceId']}',
            );

            debugPrint(
              'sequence: ${data['sequence']}',
            );

            debugPrint(
              'status: ${data['status']}',
            );

            debugPrint(
              'lastSeen: ${data['lastSeen']}',
            );

            setState(() {
              _latestTelemetry =
              Map<String, dynamic>.from(data);
            });
          },
          onError: (error) {
            debugPrint(
              '[HomePage] Telemetry listener error: $error',
            );
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

    return int.tryParse(
      value.toString(),
    );
  }

  String? _cleanDeviceId(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();

    if (result.isEmpty ||
        result == 'null') {
      return null;
    }

    return result;
  }

  // ============================================================
  // GREETING
  // ============================================================

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 4 && hour < 11) {
      return 'Selamat Pagi';
    }

    if (hour >= 11 && hour < 15) {
      return 'Selamat Siang';
    }

    if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    }

    return 'Selamat Malam';
  }

  String _getWaliName() {
    final user =
        FirebaseAuth.instance.currentUser;

    final displayName =
    user?.displayName?.trim();

    if (displayName != null &&
        displayName.isNotEmpty) {
      return displayName;
    }

    final email =
    user?.email?.trim();

    if (email != null &&
        email.isNotEmpty) {
      final name =
          email.split('@').first;

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Wali';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : _buildDashboard(context),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
      BuildContext context,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 52,
                color:
                AppTheme.primaryColor,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Belum Ada Profil Lansia',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Tambahkan profil lansia terlebih dahulu '
                  'untuk mulai menggunakan EMERYS.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: 240,
              height: 50,
              child: ElevatedButton(
                onPressed:
                widget.onAddElderlyPressed,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  AppTheme.primaryColor,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  shape:
                  const StadiumBorder(),
                ),
                child: const Text(
                  '+ Tambah Profil Lansia',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard(
      BuildContext context,
      ) {
    return RefreshIndicator(
      onRefresh:
      _loadElderlyProfile,
      child:
      SingleChildScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildHeader(context),

            Padding(
              padding:
              const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildLiveLocation(
                    context,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  _buildMetricsRow(
                    context,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  Text(
                    'Aktivitas Hari Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      Theme.of(context)
                          .colorScheme
                          .onSurface,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildActivityTimeline(
                    context,
                  ),
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

  Widget _buildHeader(
      BuildContext context,
      ) {
    return Container(
      width: double.infinity,
      decoration:
      const BoxDecoration(
        gradient: LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            Color(0xFF0D9488),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius:
        BorderRadius.only(
          bottomLeft:
          Radius.circular(40),
          bottomRight:
          Radius.circular(40),
        ),
      ),
      padding:
      const EdgeInsets.fromLTRB(
        24,
        36,
        24,
        40,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Text(
                      'Selamat Datang 👋',
                      style:
                      TextStyle(
                        color:
                        Colors.white70,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(
                        height: 2),

                    Text(
                      'Dasbor ${_getWaliName()}',
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 24,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: widget
                    .onNotificationPressed,
                child: Stack(
                  clipBehavior:
                  Clip.none,
                  children: [
                    Container(
                      padding:
                      const EdgeInsets
                          .all(8),
                      decoration:
                      BoxDecoration(
                        color: Colors
                            .white
                            .withValues(
                          alpha: 0.2,
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child:
                      const Icon(
                        Icons
                            .notifications_none,
                        color:
                        Colors.white,
                      ),
                    ),

                    Positioned(
                      right: -2,
                      top: -2,
                      child:
                      Container(
                        padding:
                        const EdgeInsets
                            .all(4),
                        decoration:
                        const BoxDecoration(
                          color: Colors.red,
                          shape:
                          BoxShape.circle,
                        ),
                        child:
                        const Text(
                          '3',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize:
                            10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 24),

          _buildElderlySummaryCard(
            context,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ELDERLY SUMMARY CARD
  // ============================================================

  Widget _buildElderlySummaryCard(
      BuildContext context,
      ) {
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

  Widget _buildElderlyInfo(
      BuildContext context,
      ) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF)
                    .withValues(alpha: 0.2),
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
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    _elderlyName ?? 'Lansia',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                    ),
                  ),

                  if (_elderlyAge != null)
                    Text(
                      'Usia $_elderlyAge tahun',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 2),

                  Text(
                    'Terakhir aktif: Belum tersedia',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      fontSize: 13,
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
              value: 'Belum tersedia',
              color: const Color(0xFF0D9488),
            ),

            const SizedBox(width: 12),

            _buildStatusSubCard(
              icon: Icons.warning_amber_rounded,
              label: 'Risiko Jatuh',
              value: 'Belum tersedia',
              color: const Color(0xFF0D9488),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddElderlyContent(
      BuildContext context,
      ) {
    return Column(
      children: [
        const SizedBox(height: 4),

        Icon(
          Icons.person_add_alt_1,
          size: 42,
          color: const Color(0xFF0D9488)
              .withValues(alpha: 0.8),
        ),

        const SizedBox(height: 12),

        Text(
          'Belum Ada Profil Lansia',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context)
                .colorScheme
                .onSurface,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Tambahkan profil lansia untuk mulai '
              'menggunakan EMERYS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
            widget.onAddElderlyPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(
                vertical: 14,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16),
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
    if (_deviceId == null || _deviceId!.isEmpty) {
      return 'Belum Terhubung';
    }

    final lastSeen = _parseLastSeen(
      _latestTelemetry?['lastSeen'],
    );

    if (lastSeen == null) {
      return 'Menunggu Data';
    }

    final difference =
    DateTime.now().difference(lastSeen);

    if (difference <= _deviceOfflineThreshold) {
      return 'Aktif';
    }

    return 'Offline';
  }

  Widget _buildDeviceStatusBadge(
      BuildContext context,
      ) {

    final status = _deviceStatusText;

    final Color dotColor;
    final Color backgroundColor;
    final Color textColor;

    if (status == 'Aktif') {
      dotColor = const Color(0xFF2DD4BF);
      backgroundColor =
          AppTheme.primaryColor.withValues(alpha: 0.15);
      textColor = const Color(0xFF0D9488);
    } else if (status == 'Offline') {
      dotColor = Colors.red;
      backgroundColor =
          Colors.red.withValues(alpha: 0.10);
      textColor = Colors.red;
    } else {
      dotColor = Colors.orange;
      backgroundColor =
          Colors.orange.withValues(alpha: 0.12);
      textColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
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
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
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
        padding:
        const EdgeInsets.all(12),
        decoration:
        BoxDecoration(
          color: color.withValues(
            alpha: 0.08,
          ),
          borderRadius:
          BorderRadius.circular(
            16,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: color.withValues(
                    alpha: 0.6,
                  ),
                ),

                const SizedBox(
                    width: 4),

                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    TextStyle(
                      color:
                      color.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
                height: 4),

            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight:
                FontWeight.bold,
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

  Widget _buildLiveLocation(
      BuildContext context,
      ) {
    final hasDevice =
        _isDeviceConnected;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color:
                  Color(0xFF0D9488),
                  size: 20,
                ),

                const SizedBox(
                    width: 8),

                Text(
                  'Lokasi Langsung',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onSurface,
                  ),
                ),
              ],
            ),

            Text(
              hasDevice
                  ? 'Belum tersedia'
                  : 'Belum terhubung',
              style:
              TextStyle(
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(
            height: 12),

        Container(
          height: 180,
          width: double.infinity,
          decoration:
          BoxDecoration(
            color: Theme.of(
              context,
            ).cardColor,
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: Theme.of(
                context,
              ).dividerColor,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    size:
                    const Size(
                      double.infinity,
                      double.infinity,
                    ),
                    painter:
                    GridPainter(),
                  ),
                ),
              ),

              Center(
                child: Icon(
                  hasDevice
                      ? Icons.location_on
                      : Icons.location_off_outlined,
                  color: hasDevice
                      ? const Color(
                      0xFF0D9488)
                      : Theme.of(
                    context,
                  )
                      .colorScheme
                      .onSurfaceVariant,
                  size: 40,
                ),
              ),

              Positioned(
                top: 16,
                right: 16,
                child:
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration:
                  BoxDecoration(
                    color: Theme.of(
                      context,
                    ).cardColor,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withValues(
                          alpha: 0.05,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child:
                  Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                        BoxDecoration(
                          color: hasDevice
                              ? Colors.green
                              : Colors.grey,
                          shape:
                          BoxShape.circle,
                        ),
                      ),

                      const SizedBox(
                          width: 6),

                      Text(
                        hasDevice
                            ? 'MENUNGGU DATA'
                            : 'TIDAK TERSEDIA',
                        style:
                        TextStyle(
                          fontSize: 10,
                          fontWeight:
                          FontWeight.bold,
                          color: hasDevice
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child:
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 12,
                              color:
                              Color(
                                0xFF0D9488,
                              ),
                            ),

                            const SizedBox(
                                width: 4),

                            Text(
                              _elderlyName ??
                                  'Lansia',
                              style:
                              TextStyle(
                                fontSize: 12,
                                fontWeight:
                                FontWeight
                                    .bold,
                                color: Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .onSurface,
                              ),
                            ),
                          ],
                        ),

                        Text(
                          hasDevice
                              ? 'Lokasi belum tersedia'
                              : 'Sandal belum terhubung',
                          style:
                          TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    Text(
                      'Belum tersedia',
                      textAlign:
                      TextAlign.right,
                      style:
                      TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // METRICS
  // ============================================================

  Widget _buildMetricsRow(
      BuildContext context,
      ) {
    return Row(
      children: [
        _buildMetricCard(
          context,
          icon:
          Icons.stacked_line_chart,
          value:
          'Belum tersedia',
          label:
          'Langkah Hari Ini',
          color:
          const Color(0xFF0D9488),
        ),

        const SizedBox(
            width: 12),

        _buildMetricCard(
          context,
          icon:
          Icons.battery_charging_full,
          value:
          'Belum tersedia',
          label:
          'Baterai',
          color:
          const Color(0xFF0D9488),
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
        padding:
        const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 8,
        ),
        decoration:
        BoxDecoration(
          color: Theme.of(context)
              .cardColor,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border: Border.all(
            color: Theme.of(
              context,
            ).dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.03,
              ),
              blurRadius: 10,
              offset:
              const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),

            const SizedBox(
                height: 12),

            Text(
              value,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurface,
                fontSize: 15,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 4),

            Text(
              label,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurfaceVariant,
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

  Widget _buildActivityTimeline(
      BuildContext context,
      ) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(20),
      decoration:
      BoxDecoration(
        color: Theme.of(context)
            .cardColor,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: Theme.of(context)
              .dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timeline_outlined,
            size: 42,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),

          const SizedBox(
              height: 12),

          Text(
            'Belum tersedia',
            style:
            TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.bold,
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .onSurface,
            ),
          ),

          const SizedBox(
              height: 6),

          Text(
            'Aktivitas akan tampil setelah '
                'sandal mengirimkan data monitoring.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .onSurfaceVariant,
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
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color = Colors.teal.withValues(
        alpha: 0.1,
      )
      ..strokeWidth = 1;

    for (
    double i = 0;
    i <= size.width;
    i += 40
    ) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    for (
    double i = 0;
    i <= size.height;
    i += 40
    ) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}