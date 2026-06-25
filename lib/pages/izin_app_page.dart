import 'package:flutter/material.dart';

class IzinAppPage extends StatefulWidget {
  const IzinAppPage({super.key});

  @override
  State<IzinAppPage> createState() => _IzinAppPageState();
}

class _IzinAppPageState extends State<IzinAppPage> {
  bool _bluetoothGranted = true;
  bool _locationGranted = true;
  bool _notificationGranted = true;

  static const Color teal = Color(0xFF0D8B94);
  static const Color darkText = Color(0xFF1E2A35);
  static const Color grayText = Color(0xFF8B96A1);
  static const Color bgColor = Color(0xFFF8FAFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Izin Aplikasi',
          style: TextStyle(
            color: darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE1E6E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPermissionTile(
                icon: Icons.bluetooth_rounded,
                title: 'Koneksi Bluetooth',
                subtitle: 'Diperlukan untuk memindai dan menghubungkan data secara real-time dengan EMERYS Smart Sandal.',
                value: _bluetoothGranted,
                onChanged: (val) => setState(() => _bluetoothGranted = val),
              ),
              const Divider(height: 1, indent: 56),
              _buildPermissionTile(
                icon: Icons.location_on_rounded,
                title: 'Akses Lokasi (GPS)',
                subtitle: 'Diperlukan untuk memantau posisi geografis lansia dan sinkronisasi titik koordinat pada peta saat darurat.',
                value: _locationGranted,
                onChanged: (val) => setState(() => _locationGranted = val),
              ),
              const Divider(height: 1, indent: 56),
              _buildPermissionTile(
                icon: Icons.notifications_active_rounded,
                title: 'Notifikasi Prioritas',
                subtitle: 'Diperlukan untuk mengirimkan suara peringatan instan (SOS) ketika sistem mendeteksi lansia jatuh.',
                value: _notificationGranted,
                onChanged: (val) => setState(() => _notificationGranted = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: teal.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: teal, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: grayText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: teal,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD4DDE0),
        ),
      ),
    );
  }

}
