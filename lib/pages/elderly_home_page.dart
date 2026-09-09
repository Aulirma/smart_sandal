import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../theme/app_theme.dart';
import 'role_gate.dart';
import '../services/backend_api_service.dart';
import '../services/emerys_ble_service.dart';

/// Halaman utama lansia.
///
/// Fungsi utama:
/// - Menghubungkan HP ke sandal EMERYS melalui BLE.
/// - Menampilkan status koneksi BLE sebenarnya.
/// - Menampilkan battery jika data sensor sudah diterima.
/// - Tombol darurat sebagai aksi sekunder.
class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() =>
      _ElderlyHomePageState();
}

enum BleConnectionState {
  disconnected,
  scanning,
  connected,
}

class _ElderlyHomePageState
    extends State<ElderlyHomePage> {

  // ============================================================
  // BLE SERVICE
  // ============================================================

  final EmerysBleService _bleService =
      EmerysBleService.instance;

  BleConnectionState _connectionState =
      BleConnectionState.disconnected;

  int? _batteryLevel;

  StreamSubscription<BleConnectionStatus>?
  _bleStatusSubscription;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Dengarkan perubahan status BLE
    _bleStatusSubscription =
        _bleService.statusStream.listen(
          _onBleStatusChanged,
        );

    // Kalau service ternyata sudah connected
    if (_bleService.isConnected) {
      _connectionState =
          BleConnectionState.connected;
    }
  }

  // ============================================================
  // BLE STATUS
  // ============================================================

  void _onBleStatusChanged(
      BleConnectionStatus status,
      ) {
    if (!mounted) return;

    switch (status) {
      case BleConnectionStatus.disconnected:
        setState(() {
          _connectionState =
              BleConnectionState.disconnected;

          _batteryLevel = null;
        });
        break;

      case BleConnectionStatus.scanning:
      case BleConnectionStatus.connecting:
        setState(() {
          _connectionState =
              BleConnectionState.scanning;
        });
        break;

      case BleConnectionStatus.connected:
        setState(() {
          _connectionState =
              BleConnectionState.connected;
        });
        break;
    }
  }

  // ============================================================
  // SCAN + PILIH DEVICE + CONNECT
  // ============================================================

  Future<void> _connectToSandal() async {
    // Jangan scan lagi kalau sedang scanning
    if (_connectionState ==
        BleConnectionState.scanning) {
      return;
    }

    setState(() {
      _connectionState =
          BleConnectionState.scanning;

      _batteryLevel = null;
    });

    try {
      // ========================================================
      // 1. SCAN PERANGKAT BLE
      // ========================================================

      final devices =
      await _bleService.scanDevices();

      if (!mounted) return;

      // Setelah scan selesai, status sementara kembali
      // menjadi disconnected sampai user memilih device.
      setState(() {
        _connectionState =
            BleConnectionState.disconnected;
      });

      // ========================================================
      // 2. TIDAK ADA DEVICE
      // ========================================================

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada perangkat Bluetooth yang ditemukan.',
            ),
            duration: Duration(seconds: 3),
          ),
        );

        return;
      }

      // ========================================================
      // 3. TAMPILKAN POPUP DEVICE
      // ========================================================

      final selectedDevice =
      await _showBluetoothDeviceDialog(
        devices,
      );

      if (!mounted || selectedDevice == null) {
        return;
      }

      // ========================================================
      // 4. CONNECT KE DEVICE YANG DIPILIH
      // ========================================================

      setState(() {
        _connectionState =
            BleConnectionState.scanning;
      });

      final success =
      await _bleService.connectToDevice(
        selectedDevice,
      );

      if (!mounted) return;

      // ========================================================
      // 5. BERHASIL
      // ========================================================

      if (success) {
        setState(() {
          _connectionState =
              BleConnectionState.connected;
        });

        final deviceName =
        selectedDevice.platformName.isNotEmpty
            ? selectedDevice.platformName
            : 'perangkat BLE';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil terhubung ke $deviceName.',
            ),
            duration:
            const Duration(seconds: 3),
          ),
        );

        return;
      }

      // ========================================================
      // 6. GAGAL CONNECT
      // ========================================================

      setState(() {
        _connectionState =
            BleConnectionState.disconnected;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menghubungkan ke perangkat.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connectionState =
            BleConnectionState.disconnected;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal melakukan scan Bluetooth: $e',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================================
  // POPUP DAFTAR PERANGKAT BLE
  // ============================================================

  Future<BluetoothDevice?>
  _showBluetoothDeviceDialog(
      List<ScanResult> devices,
      ) async {
    return showDialog<BluetoothDevice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bluetooth),
              SizedBox(width: 10),
              Text('Pilih Perangkat'),
            ],
          ),

          content: SizedBox(
            width: double.maxFinite,

            child: ListView.separated(
              shrinkWrap: true,

              itemCount: devices.length,

              separatorBuilder: (_, __) =>
              const Divider(),

              itemBuilder: (context, index) {
                final result = devices[index];

                final device =
                    result.device;

                final name =
                device.platformName.isNotEmpty
                    ? device.platformName
                    : 'Perangkat Tidak Dikenal';

                // Tandai device EMERYS
                final isEmerys =
                    name == 'EMERYS Smart';

                return ListTile(
                  leading: Icon(
                    isEmerys
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,

                    color: isEmerys
                        ? Colors.green
                        : Colors.grey,
                  ),

                  title: Text(
                    name,

                    style: TextStyle(
                      fontWeight: isEmerys
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),

                  subtitle: Text(
                    '${device.remoteId}\n'
                        'Signal: ${result.rssi} dBm',
                  ),

                  isThreeLine: true,

                  trailing: const Icon(
                    Icons.chevron_right,
                  ),

                  onTap: () {
                    Navigator.pop(
                      context,
                      device,
                    );
                  },
                );
              },
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text(
                'Batal',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> _disconnect() async {
    try {
      await _bleService.disconnect();
    } catch (e) {
      debugPrint(
        'BLE disconnect error: $e',
      );
    }

    if (!mounted) return;

    setState(() {
      _connectionState =
          BleConnectionState.disconnected;

      _batteryLevel = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sandal telah diputuskan.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _confirmLogout(
      BuildContext context,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,

      builder: (context) =>
          AlertDialog(
            title: const Text(
              'Keluar dari akun ini?',
            ),

            content: const Text(
              'HP ini akan berhenti terhubung ke sandal sampai login ulang.',
            ),

            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),

                child: const Text(
                  'Batal',
                ),
              ),

              ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),

                onPressed: () =>
                    Navigator.pop(
                      context,
                      true,
                    ),

                child: const Text(
                  'Keluar',

                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true &&
        context.mounted) {

      // Putuskan BLE sebelum logout
      await _bleService.disconnect();

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
            const RoleGate(),
          ),
              (route) => false,
        );
      }
    }
  }

  // ============================================================
  // EMERGENCY
  // ============================================================

  Future<void> _sendEmergency(
      BuildContext context,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,

      builder: (context) =>
          AlertDialog(
            title: const Text(
              'Kirim Peringatan Darurat?',
            ),

            content: const Text(
              'Wali akan segera mendapat notifikasi.',
            ),

            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),

                child: const Text(
                  'Batal',
                ),
              ),

              ElevatedButton(
                style:
                ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),

                onPressed: () =>
                    Navigator.pop(
                      context,
                      true,
                    ),

                child: const Text(
                  'Kirim',

                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true ||
        !context.mounted) {
      return;
    }

    try {
      await BackendApiService()
          .sendFallEvent(
        severity: 'manual',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Peringatan terkirim ke wali.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim: $e',
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bleStatusSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isConnected =
        _connectionState ==
            BleConnectionState.connected;

    final isScanning =
        _connectionState ==
            BleConnectionState.scanning;

    return Scaffold(
      backgroundColor:
      Theme.of(context)
          .scaffoldBackgroundColor,

      body: SafeArea(
        child: Stack(
          children: [

            // ==================================================
            // SETTINGS
            // ==================================================

            Align(
              alignment: Alignment.topRight,

              child: IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: Colors.grey[400],
                  size: 22,
                ),

                onPressed: () =>
                    _confirmLogout(
                      context,
                    ),
              ),
            ),

            Padding(
              padding:
              const EdgeInsets.all(24.0),

              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  // ==================================================
                  // STATUS KONEKSI
                  // ==================================================

                  Container(
                    padding:
                    const EdgeInsets.all(24),

                    decoration:
                    BoxDecoration(
                      color: isConnected
                          ? Colors.green.withValues(
                        alpha: 0.1,
                      )
                          : Colors.grey.withValues(
                        alpha: 0.1,
                      ),

                      borderRadius:
                      BorderRadius.circular(24),
                    ),

                    child: Column(
                      children: [

                        Icon(
                          isConnected
                              ? Icons
                              .bluetooth_connected
                              : Icons
                              .bluetooth_disabled,

                          size: 64,

                          color: isConnected
                              ? Colors.green
                              : Colors.grey,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Text(
                          isConnected
                              ? 'Sandal Terhubung'
                              : isScanning
                              ? 'Mencari Sandal...'
                              : 'Sandal Belum Terhubung',

                          style:
                          const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                          ),

                          textAlign:
                          TextAlign.center,
                        ),

                        // ==================================================
                        // BATTERY
                        // ==================================================

                        if (isConnected &&
                            _batteryLevel != null) ...[
                          const SizedBox(
                            height: 12,
                          ),

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .center,

                            children: [
                              const Icon(
                                Icons
                                    .battery_charging_full,
                                size: 24,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Text(
                                'Baterai: $_batteryLevel%',

                                style:
                                const TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  // ==================================================
                  // BUTTON CONNECT
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 72,

                    child:
                    ElevatedButton.icon(
                      onPressed: isScanning
                          ? null
                          : (isConnected
                          ? _disconnect
                          : _connectToSandal),

                      icon: isScanning
                          ? const SizedBox(
                        width: 20,
                        height: 20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )

                          : Icon(
                        isConnected
                            ? Icons.link_off
                            : Icons
                            .bluetooth_searching,
                        size: 28,
                      ),

                      label: Text(
                        isConnected
                            ? 'Putuskan Koneksi'
                            : isScanning
                            ? 'Menghubungkan...'
                            : 'Hubungkan ke Sandal',

                        style:
                        const TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        isConnected
                            ? Colors.grey[700]
                            : AppTheme
                            .primaryColor,

                        foregroundColor:
                        Colors.white,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 48,
                  ),

                  Divider(
                    color: Colors.grey[300],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // EMERGENCY
                  // ==================================================

                  TextButton.icon(
                    onPressed: () =>
                        _sendEmergency(
                          context,
                        ),

                    icon: const Icon(
                      Icons
                          .warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),

                    label: const Text(
                      'Kirim Peringatan Darurat',

                      style: TextStyle(
                        color: Colors.red,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}