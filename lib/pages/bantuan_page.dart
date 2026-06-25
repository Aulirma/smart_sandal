import 'package:flutter/material.dart';

class BantuanPage extends StatelessWidget {
  const BantuanPage({super.key});

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
          'Bantuan & Dukungan',
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
            // Section 1 Heading
            const Padding(
              padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'PERTANYAAN POPULER (FAQ)',
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
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: Column(
                  children: [
                    _buildExpansionTile(
                      context,
                      title: 'Bagaimana cara menghubungkan sandal?',
                      subtitle: 'Pastikan Bluetooth ponsel Anda aktif, lalu buka menu Manajemen Perangkat dan pilih \'EMERYS Smart Sandal\' untuk memulai pairing.',
                      iconColor: teal,
                    ),
                    const Divider(height: 1, color: Color(0xFFE1E6E8)),
                    _buildExpansionTile(
                      context,
                      title: 'Mengapa lokasi GPS lansia tidak akurat?',
                      subtitle: 'Modul GPS membutuhkan waktu beberapa saat untuk mengunci satelit. Pastikan lansia berada di area terbuka atau dekat jendela untuk akurasi terbaik.',
                      iconColor: teal,
                    ),
                    const Divider(height: 1, color: Color(0xFFE1E6E8)),
                    _buildExpansionTile(
                      context,
                      title: 'Kapan alarm darurat (SOS) akan berbunyi?',
                      subtitle: 'Alarm akan berbunyi otomatis di ponsel pendamping jika sistem TinyML pada sandal mendeteksi akselerasi ekstrem atau perubahan orientasi yang mengindikasikan lansia terjatuh.',
                      iconColor: teal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'HUBUNGI KAMI',
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
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_rounded, color: teal, size: 22),
                    ),
                    title: const Text(
                      'Chat Customer Service',
                      style: TextStyle(fontWeight: FontWeight.bold, color: darkText, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Hubungi tim teknis EMERYS via WhatsApp (24/7)',
                      style: TextStyle(color: grayText, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: grayText),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membuka WhatsApp Chat...')),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFE1E6E8)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.email_rounded, color: teal, size: 22),
                    ),
                    title: const Text(
                      'Kirim Email Dukungan',
                      style: TextStyle(fontWeight: FontWeight.bold, color: darkText, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'support@emerys.id',
                      style: TextStyle(color: grayText, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: grayText),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Membuka Aplikasi Email...')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return ExpansionTile(
      iconColor: iconColor,
      collapsedIconColor: Colors.grey,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E2A35),
          fontSize: 15,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
