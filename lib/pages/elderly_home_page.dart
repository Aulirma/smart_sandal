import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'role_gate.dart';
import '../services/backend_api_service.dart';
// import '../services/emerys_ble_service.dart'; // TODO: sambungkan ke BLE service asli di sini

/// Ditaruh di lib/pages/elderly_home_page.dart
///
/// Fokus utama halaman ini: MENYAMBUNGKAN ke sandal via BLE.
/// Tombol darurat cuma jadi aksi sekunder (kecil, di bawah), karena
/// fungsi utama HP lansia adalah jadi jembatan data sandal -> cloud,
/// bukan dioperasikan aktif oleh lansia.
class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() => _ElderlyHomePageState();
}

enum BleConnectionState { disconnected, scanning, connected }

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  int? _batteryLevel;

  Future<void> _connectToSandal() async {
    setState(() => _connectionState = BleConnectionState.scanning);

    // TODO: ganti simulasi ini dengan pemanggilan asli ke emerys_ble_service.dart
    // Contoh nanti: final device = await EmerysBleService().scanAndConnect();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _connectionState = BleConnectionState.connected;
      _batteryLevel = 78; // TODO: ambil dari data BLE asli
    });
  }

  void _disconnect() {
    // TODO: panggil EmerysBleService().disconnect() di sini
    setState(() {
      _connectionState = BleConnectionState.disconnected;
      _batteryLevel = null;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun ini?'),
        content: const Text(
            'HP ini akan berhenti terhubung ke sandal sampai login ulang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleGate()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _sendEmergency(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Peringatan Darurat?'),
        content: const Text('Wali akan segera mendapat notifikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await BackendApiService().sendFallEvent(severity: 'manual');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peringatan terkirim ke wali.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == BleConnectionState.connected;
    final isScanning = _connectionState == BleConnectionState.scanning;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.settings_outlined, color: Colors.grey[400], size: 22),
                onPressed: () => _confirmLogout(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Status koneksi ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          size: 64,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isConnected
                              ? 'Sandal Terhubung'
                              : isScanning
                              ? 'Mencari Sandal...'
                              : 'Sandal Belum Terhubung',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (isConnected && _batteryLevel != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.battery_charging_full, size: 24),
                              const SizedBox(width: 8),
                              Text('Baterai: $_batteryLevel%', style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Tombol utama: Hubungkan / Putuskan ---
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: isScanning
                          ? null
                          : (isConnected ? _disconnect : _connectToSandal),
                      icon: isScanning
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Icon(isConnected ? Icons.link_off : Icons.bluetooth_searching, size: 28),
                      label: Text(
                        isConnected
                            ? 'Putuskan Koneksi'
                            : isScanning
                            ? 'Menghubungkan...'
                            : 'Hubungkan ke Sandal',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? Colors.grey[700] : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),

                  // --- Tombol darurat: sekarang jadi sekunder, lebih kecil ---
                  TextButton.icon(
                    onPressed: () => _sendEmergency(context),
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    label: const Text(
                      'Kirim Peringatan Darurat',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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