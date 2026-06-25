import 'package:flutter/material.dart';

class LaporanHarianPage extends StatelessWidget {
  const LaporanHarianPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color teal = Color(0xFF0D8B94);
    const Color darkText = Color(0xFF1E2A35);
    const Color grayText = Color(0xFF8B96A1);
    const Color bgColor = Color(0xFFF8FAFB);

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
          'Laporan Harian',
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E6E8)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Kestabilan Langkah',
                              style: TextStyle(
                                color: grayText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '85% (Stabil / Risiko Jatuh Rendah)',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: teal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_walk_rounded, color: teal, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Langkah Hari Ini',
                              style: TextStyle(
                                color: grayText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '2.450 Langkah',
                              style: TextStyle(
                                color: darkText,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'LOG RIWAYAT AKTIVITAS',
                style: TextStyle(
                  color: grayText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1E6E8)),
              ),
              child: Column(
                children: [
                  _buildLogItem(
                    icon: Icons.report_problem_rounded,
                    iconColor: Colors.red,
                    title: '09:15 WIB - Terdeteksi Jatuh (Kritis)',
                    subtitle: 'Sistem mendeteksi insiden jatuh pada lansia. Status: Teratasi oleh Pendamping.',
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildLogItem(
                    icon: Icons.trending_down_rounded,
                    iconColor: Colors.orange,
                    title: '14:30 WIB - Kestabilan Langkah Menurun',
                    subtitle: 'Tumpuan kaki kiri dan kanan tidak seimbang dalam durasi 5 menit (Risiko Jatuh Sedang).',
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildLogItem(
                    icon: Icons.directions_walk_rounded,
                    iconColor: teal,
                    title: '17:00 WIB - Aktivitas Berjalan Sore',
                    subtitle: 'Lansia melakukan aktivitas berjalan dengan pola langkah yang stabil dan normal.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2A35),
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
