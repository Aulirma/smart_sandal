import 'package:flutter/material.dart';

class BantuanPage extends StatelessWidget {
  const BantuanPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color teal = Color(0xFF0D8B94);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bantuan & Dukungan',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'PERTANYAAN POPULER (FAQ)',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                      subtitle:
                          'Pastikan Bluetooth ponsel Anda aktif, lalu buka menu Manajemen Perangkat dan pilih \'EMERYS Smart Sandal\' untuk memulai pairing.',
                      iconColor: teal,
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _buildExpansionTile(
                      context,
                      title: 'Mengapa lokasi GPS lansia tidak akurat?',
                      subtitle:
                          'Modul GPS membutuhkan waktu beberapa saat untuk mengunci satelit. Pastikan lansia berada di area terbuka atau dekat jendela untuk akurasi terbaik.',
                      iconColor: teal,
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    _buildExpansionTile(
                      context,
                      title: 'Kapan alarm darurat (SOS) akan berbunyi?',
                      subtitle:
                          'Alarm akan berbunyi otomatis di ponsel pendamping jika sistem TinyML pada sandal mendeteksi akselerasi ekstrem atau perubahan orientasi yang mengindikasikan lansia terjatuh.',
                      iconColor: teal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'HUBUNGI KAMI',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
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
                      child:
                          const Icon(Icons.chat_rounded, color: teal, size: 22),
                    ),
                    title: Text(
                      'Chat Customer Service',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15),
                    ),
                    subtitle: Text(
                      'Hubungi tim teknis EMERYS via WhatsApp (24/7)',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Membuka WhatsApp Chat...')),
                      );
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.email_rounded, color: teal, size: 22),
                    ),
                    title: Text(
                      'Kirim Email Dukungan',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15),
                    ),
                    subtitle: Text(
                      'support@emerys.id',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Membuka Aplikasi Email...')),
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
