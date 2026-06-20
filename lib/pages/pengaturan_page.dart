import 'package:flutter/material.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  bool pushNotif = true;
  bool smsDarurat = true;
  bool laporanHarian = true;
  bool pushNotif2 = true;
  bool smsDarurat2 = true;
  bool laporanHarian2 = true;
  bool modeGelap = true;

  static const Color teal = Color(0xFF2FB4A6);
  static const Color darkText = Color(0xFF1E2A35);
  static const Color grayText = Color(0xFF8B96A1);
  static const Color bgColor = Color(0xFFF8FAFB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildProfileCard(),
              const SizedBox(height: 20),
              _buildNotificationCard(
                pushValue: pushNotif,
                smsValue: smsDarurat,
                reportValue: laporanHarian,
                onPushChanged: (value) => setState(() => pushNotif = value),
                onSmsChanged: (value) => setState(() => smsDarurat = value),
                onReportChanged: (value) => setState(() => laporanHarian = value),
              ),
              const SizedBox(height: 20),
              _buildNotificationCard(
                pushValue: pushNotif2,
                smsValue: smsDarurat2,
                reportValue: laporanHarian2,
                onPushChanged: (value) => setState(() => pushNotif2 = value),
                onSmsChanged: (value) => setState(() => smsDarurat2 = value),
                onReportChanged: (value) => setState(() => laporanHarian2 = value),
              ),
              const SizedBox(height: 20),
              _buildGeneralCard(),
              const SizedBox(height: 22),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: darkText,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 18),
        const Text(
          'Pengaturan',
          style: TextStyle(
            color: darkText,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sarah Ahmad',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'sarah@email.com',
                      style: TextStyle(
                        color: grayText,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: grayText, size: 32),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(color: Color(0xFFE2E7E9), thickness: 1),
          const SizedBox(height: 10),
          _menuTile(
            icon: Icons.person_outline,
            title: 'Ubah Profil',
            trailing: const Icon(Icons.chevron_right, color: grayText, size: 30),
          ),
          _menuTile(
            icon: Icons.shield_outlined,
            title: 'Ubah Kata Sandi',
            trailing: const Icon(Icons.chevron_right, color: grayText, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required bool pushValue,
    required bool smsValue,
    required bool reportValue,
    required ValueChanged<bool> onPushChanged,
    required ValueChanged<bool> onSmsChanged,
    required ValueChanged<bool> onReportChanged,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTIFIKASI',
            style: TextStyle(
              color: grayText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          _menuTile(
            icon: Icons.notifications_none,
            title: 'Notifikasi Push',
            trailing: _switch(pushValue, onPushChanged),
          ),
          _menuTile(
            icon: Icons.phone_outlined,
            title: 'Peringatan SMS Darurat',
            trailing: _switch(smsValue, onSmsChanged),
          ),
          _menuTile(
            icon: Icons.notifications_none,
            title: 'Laporan Harian',
            trailing: _switch(reportValue, onReportChanged),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UMUM',
            style: TextStyle(
              color: grayText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          _menuTile(
            icon: Icons.phone_outlined,
            title: 'Kontak Darurat',
            trailing: const Icon(Icons.chevron_right, color: grayText, size: 30),
          ),
          _menuTile(
            icon: Icons.dark_mode_outlined,
            title: 'Mode Gelap',
            trailing: _switch(modeGelap, (value) {
              setState(() => modeGelap = value);
            }),
          ),
          _menuTile(
            icon: Icons.help_outline,
            title: 'Bantuan & Dukungan',
            trailing: const Icon(Icons.chevron_right, color: grayText, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Color(0xFFE14B4B), size: 28),
        label: const Text(
          'Keluar',
          style: TextStyle(
            color: Color(0xFFE14B4B),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDF1F1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE1E6E8)),
      ),
      child: child,
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: teal, size: 30),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: darkText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: teal,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD4DDE0),
    );
  }
}