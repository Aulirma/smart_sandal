import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LegalPolicyPage extends StatelessWidget {
  const LegalPolicyPage({super.key});

  void _showPolicyDialog(BuildContext context, String title) {
    String contentText = '';

    if (title == 'Syarat & Ketentuan') {
      contentText = 'Terakhir Diperbarui: Juni 2026\n\n'
          'Selamat datang di EMERYS Mobile Application. Mohon untuk membaca Syarat dan Ketentuan ini secara saksama sebelum menggunakan aplikasi kami. Dengan mengakses dan menggunakan aplikasi EMERYS, Anda menyatakan menyetujui seluruh ketentuan di bawah ini.\n\n'
          '1. Definisi dan Lingkup Layanan\n'
          '• EMERYS adalah platform telemonitoring kesehatan terintegrasi yang dirancang untuk mitigasi risiko jatuh dan pemantauan kestabilan langkah lansia.\n'
          '• Aplikasi ini bekerja dengan menghubungkan perangkat Smart Wearable Sandal (berbasis IoT dan TinyML) milik lansia dengan perangkat smartphone milik Anda sebagai Pendamping/Wali.\n\n'
          '2. Registrasi Akun Pendamping\n'
          '• Untuk menggunakan layanan ini, Pendamping wajib memberikan informasi yang akurat, meliputi Nama Lengkap, Tanggal Lahir, Email, Nomor Telepon, Alamat, dan Kata Sandi.\n'
          '• Anda bertanggung jawab penuh untuk menjaga kerahasiaan akun dan setiap aktivitas yang terjadi di bawah akun Anda.\n\n'
          '3. Pengisian Data Lansia\n'
          '• Pendamping diberikan hak untuk menambahkan data profil lansia yang dipantau, termasuk Nama, Usia, dan Catatan Kesehatan/Riwayat Medis.\n'
          '• Pendamping menjamin bahwa penambahan data tersebut telah mendapatkan persetujuan dari pihak lansia yang bersangkutan atau keluarga inti yang berwenang.\n\n'
          '4. Integrasi Perangkat Pintar (Smart Sandal)\n'
          '• Penggunaan fitur pemantauan secara penuh memerlukan konektivitas Bluetooth Low Energy (BLE) yang aktif antara smartphone dan Box Electrical EMERYS Smart Sandal.\n'
          '• Aplikasi akan mengolah data mentah dari sensor Accelerometer, Gyroscope, dan sensor tekanan (Force Sensitive Resistor) untuk ditampilkan pada halaman pemantauan.\n\n'
          '5. Batasan Tanggung Jawab\n'
          '• EMERYS adalah alat bantu mitigasi dan telemonitoring dini. Sistem klasifikasi berbasis TinyML di dalam sandal dirancang untuk mendeteksi anomali langkah dan indikasi jatuh berdasarkan algoritma komputasi.\n'
          '• EMERYS bukan merupakan pengganti dari pengawasan medis profesional, penanganan dokter, ataupun tindakan darurat medis utama.\n'
          '• Pengembang tidak bertanggung jawab atas kegagalan pengiriman sinyal darurat (SOS) yang disebabkan oleh gangguan sinyal seluler, matinya daya baterai perangkat, kegagalan modul GPS, atau kendala teknis perangkat keras di luar kendali sistem aplikasi.\n\n'
          '6. Hak Kekayaan Intelektual\n'
          '• Seluruh arsitektur kode, desain antarmuka (UI/UX), logo, merek, dan algoritma TinyML yang melekat pada aplikasi EMERYS merupakan Hak Kekayaan Intelektual (HKI) dari Tim Pengusul PKM-KC EMERYS Universitas Negeri Surabaya.';
    } else if (title == 'Kebijakan Privasi') {
      contentText = 'Terakhir Diperbarui: Juni 2026\n\n'
          'Kami di EMERYS berkomitmen penuh untuk melindungi privasi Anda dan lansia yang Anda pantau. Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, menyimpan, dan melindungi informasi sensitif Anda.\n\n'
          '1. Informasi yang Kami Kumpulkan\n'
          '• Data Identitas Pendamping: Nama Lengkap, Tanggal Lahir, Email, Nomor Telepon, dan Alamat Pendamping.\n'
          '• Data Identitas Lansia: Nama, Usia, dan Catatan Riwayat Kesehatan.\n'
          '• Data Sensor Perangkat (Smart Sandal): Data orientasi gerak dari sensor MPU6050 (Gyroscope dan Accelerometer), data gaya tekan dari sensor FSR 402 (Pressure Sensor), tingkat daya baterai sandal, serta status konektivitas perangkat.\n'
          '• Data Geolokasi: Koordinat titik lintang dan bujur (Latitude & Longitude) yang ditangkap oleh modul GPS Neo 6M pada sandal pintar untuk melacak lokasi terkini lansia ketika keadaan darurat terjadi.\n\n'
          '2. Penggunaan Informasi\n'
          'Data yang dikumpulkan digunakan secara eksklusif untuk fungsi-fungsi berikut:\n'
          '• Memproses algoritma Machine Learning lokal (TinyML) guna menganalisis kestabilan langkah dan mengklasifikasikan risiko jatuh secara real-time.\n'
          '• Menampilkan visualisasi grafik heatmap tumpuan kaki lansia pada halaman "Pantau" aplikasi.\n'
          '• Mengirimkan notifikasi peringatan (Push Notification) dan koordinat peta darurat kepada nomor Kontak Darurat yang telah didaftarkan saat sistem mendeteksi lansia jatuh.\n\n'
          '3. Izin Aplikasi pada Smartphone (App Permissions)\n'
          'Untuk mengoperasikan fitur pemantauan, aplikasi EMERYS akan meminta izin akses pada sistem operasi ponsel Anda berupa:\n'
          '• Izin Bluetooth: Digunakan untuk memindai dan menyambungkan koneksi data dengan sandal pintar secara konstan.\n'
          '• Izin Lokasi (GPS): Digunakan untuk sinkronisasi peta penunjuk arah antara lokasi pendamping dan lokasi koordinat sandal lansia.\n'
          '• Izin Notifikasi: Wajib diaktifkan agar aplikasi dapat memberikan suara/getaran peringatan berprioritas tinggi jika terjadi insiden jatuh.\n\n'
          '4. Keamanan dan Penyimpanan Data\n'
          '• Seluruh data mentah sensor gerak diproses secara langsung di tingkat lokal (Edge Computing) pada sandal pintar untuk meminimalkan kebocoran data di jaringan Internet.\n'
          '• Data profil personal dan log riwayat kesehatan disimpan menggunakan enkripsi standar industri untuk mencegah akses tidak sah dari pihak ketiga.\n\n'
          '5. Pengungkapan Data Pihak Ketiga\n'
          'Kami tidak akan pernah menjual, menyewakan, atau menyebarkan data pribadi Anda atau data medis lansia kepada pihak ketiga komersial mana pun. Data lokasi dan status darurat hanya akan diteruskan kepada Kontak Darurat yang telah Anda tentukan sendiri di dalam aplikasi.';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            contentText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          'Legalitas & Privasi',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.gavel_rounded,
                  color: AppTheme.primaryColor,
                ),

                title: Text(
                  'Syarat & Ketentuan',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => _showPolicyDialog(context, 'Syarat & Ketentuan'),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_rounded,
                  color: AppTheme.primaryColor,
                ),

                title: Text(
                  'Kebijakan Privasi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => _showPolicyDialog(context, 'Kebijakan Privasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
