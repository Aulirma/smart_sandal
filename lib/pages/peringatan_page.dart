import 'package:flutter/material.dart';

class PeringatanPage extends StatelessWidget {
  const PeringatanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            // Logic for back button
          },
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
            onPressed: () {},
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
              // 2. Kartu Protokol Darurat Aktif (Urgent Card - Merah)
              _buildUrgentCard(),
              const SizedBox(height: 24),
              
              // 3. Daftar Riwayat Peringatan (Notification List)
              const Text(
                'Riwayat Peringatan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildNotificationItem(
                icon: Icons.shield_outlined,
                iconBgColor: Colors.red[50]!,
                iconColor: Colors.red[900]!,
                title: 'Peringatan Risiko Jatuh',
                subtitle: 'Risiko jatuh tinggi terdeteksi – pola langkah abnormal',
                timeLocation: '2 menit lalu  •  Taman Sri Muda, Shah Alam',
                hasDot: true,
              ),
              const SizedBox(height: 12),
              
              _buildNotificationItem(
                icon: Icons.warning_amber_rounded,
                iconBgColor: Colors.orange[50]!,
                iconColor: Colors.orange[800]!,
                title: 'Langkah Tidak Stabil',
                subtitle: 'Periode langkah tidak stabil terdeteksi sesaat',
                timeLocation: '15 menit lalu  •  Dekat area pasar',
                hasDot: true,
              ),
              const SizedBox(height: 12),
              
              _buildNotificationItem(
                icon: Icons.warning_amber_rounded,
                iconBgColor: Colors.orange[50]!,
                iconColor: Colors.orange[800]!,
                title: 'Baterai Rendah',
                subtitle: 'Baterai sandal pintar tersisa 15%',
                timeLocation: '1 jam lalu',
                hasDot: true,
              ),
              const SizedBox(height: 12),
              
              _buildNotificationItem(
                icon: Icons.notifications_none,
                iconBgColor: Colors.green[50]!,
                iconColor: Colors.green[800]!,
                title: 'Perangkat Tersinkronisasi',
                subtitle: 'Data berhasil disinkronkan ke cloud',
                timeLocation: '3 jam lalu',
                hasCheck: true,
              ),
              const SizedBox(height: 12),
              
              _buildNotificationItem(
                icon: Icons.check,
                iconBgColor: Colors.green[50]!,
                iconColor: Colors.green[800]!,
                title: 'Laporan Harian Siap',
                subtitle: 'Laporan aktivitas kemarin telah siap diulas',
                timeLocation: 'Tadi pagi',
                hasCheck: true,
              ),
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
                
                // Mock Map
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
                          color: Colors.green[50],
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
              onPressed: () {},
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

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeLocation,
    bool hasDot = false,
    bool hasCheck = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    if (hasDot)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasCheck)
                      const Icon(Icons.check_circle_outline, color: Colors.grey, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeLocation,
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
    );
  }
}
