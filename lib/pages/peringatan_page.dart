import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'laporan_harian_page.dart';

class _NotificationItem {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String timeLocation;
  bool isRead;
  final bool hasCheck;

  _NotificationItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timeLocation,
    this.isRead = false,
    this.hasCheck = false,
  });
}

class PeringatanPage extends StatefulWidget {
  final VoidCallback onBackPressed;
  const PeringatanPage({super.key, required this.onBackPressed});

  @override
  State<PeringatanPage> createState() => _PeringatanPageState();
}

class _PeringatanPageState extends State<PeringatanPage> {
  final List<_NotificationItem> _notifications = [
    _NotificationItem(
      icon: Icons.shield_outlined,
      iconBgColor: const Color(0xFFFFEBEE),
      iconColor: const Color(0xFFB71C1C),
      title: 'Peringatan Risiko Jatuh',
      subtitle: 'Risiko jatuh tinggi terdeteksi – pola langkah abnormal',
      timeLocation: '2 menit lalu  •  Taman Sri Muda, Shah Alam',
    ),
    _NotificationItem(
      icon: Icons.warning_amber_rounded,
      iconBgColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFEF6C00),
      title: 'Langkah Tidak Stabil',
      subtitle: 'Periode langkah tidak stabil terdeteksi sesaat',
      timeLocation: '15 menit lalu  •  Dekat area pasar',
    ),
    _NotificationItem(
      icon: Icons.warning_amber_rounded,
      iconBgColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFEF6C00),
      title: 'Baterai Rendah',
      subtitle: 'Baterai sandal pintar tersisa 15%',
      timeLocation: '1 jam lalu',
    ),
    _NotificationItem(
      icon: Icons.notifications_none,
      iconBgColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF2E7D32),
      title: 'Perangkat Tersinkronisasi',
      subtitle: 'Data berhasil disinkronkan ke cloud',
      timeLocation: '3 jam lalu',
      isRead: true,
      hasCheck: true,
    ),
    _NotificationItem(
      icon: Icons.check,
      iconBgColor: const Color(0xFFE8F5E9),
      iconColor: const Color(0xFF2E7D32),
      title: 'Laporan Harian Siap',
      subtitle: 'Laporan aktivitas kemarin telah siap diulas',
      timeLocation: 'Tadi pagi',
      isRead: true,
      hasCheck: true,
    ),
  ];

  Future<void> _makeEmergencyCall() async {
    const String phoneNumber = '081332190177';
    final Uri launchUri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi telepon.')),
        );
      }
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBackPressed,
        ),
        title: const Text(
          'Peringatan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Tandai semua dibaca',
              style: TextStyle(
                color: Color(0xFF0D9488),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUrgentCard(),
              const SizedBox(height: 24),
              const Text(
                'Riwayat Peringatan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ..._notifications.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildNotificationItem(item),
              )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.red[900], size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protokol Darurat Aktif',
                    style: TextStyle(
                      color: Colors.red[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Risiko jatuh tinggi terdeteksi.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Kontak darurat telah diberitahu.',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lokasi Terakhir Diketahui',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.location_on, color: Colors.green, size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LANGSUNG',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Taman Sri Muda, Shah Alam',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    Text(
                      '3.0089° N, 101.5432° E',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _makeEmergencyCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text(
                'Hubungi Kontak Darurat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(_NotificationItem item) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.title == 'Laporan Harian Siap'
            ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LaporanHarianPage(),
            ),
          );
        }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.isRead ? Colors.white : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (item.hasCheck)
                          const Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.timeLocation,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
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