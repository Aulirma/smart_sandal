import 'package:flutter/material.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'legal_policy_page.dart';
import 'izin_app_page.dart';
import 'bantuan_page.dart';
import 'login_page.dart';
import 'laporan_harian_page.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class PengaturanPage extends StatefulWidget {
  final VoidCallback onBackPressed;
  const PengaturanPage({super.key, required this.onBackPressed});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  bool pushNotif = true;
  bool smsDarurat = true;
  bool laporanHarian = true;
  bool modeGelap = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildProfileCard(),
              const SizedBox(height: 18),
              _buildNotificationCard(
                pushValue: pushNotif,
                smsValue: smsDarurat,
                reportValue: laporanHarian,
                onPushChanged: (value) => setState(() => pushNotif = value),
                onSmsChanged: (value) => setState(() => smsDarurat = value),
                onReportChanged: (value) => setState(() => laporanHarian = value),
              ),
              const SizedBox(height: 20),
              _buildGeneralCard(),
              const SizedBox(height: 18),
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
          onTap: widget.onBackPressed,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            )
          ),
        ),
        const SizedBox(width: 18),
        Text(
          'Pengaturan',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return _card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sarah Ahmad',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'sarah@email.com',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Divider(
            color: Theme.of(context).dividerColor,
            thickness: 1,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
              );
            },
            child: _menuTile(
              icon: Icons.shield_outlined,
              title: 'Ubah Kata Sandi',
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const IzinAppPage()),
              );
            },
            child: _menuTile(
              icon: Icons.security_rounded,
              title: 'Izin Aplikasi',
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
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
          Text(
            'NOTIFIKASI',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LaporanHarianPage()),
              );
            },
            child: _menuTile(
              icon: Icons.notifications_none,
              title: 'Laporan Harian',
              trailing: _switch(reportValue, onReportChanged),
            ),
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
          Text(
            'UMUM',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          _menuTile(
            icon: Icons.phone_outlined,
            title: 'Kontak Darurat',
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          _menuTile(
            icon: Icons.dark_mode_outlined,
            title: 'Mode Gelap',
            trailing: _switch(
              themeController.isDarkMode,
                  (value) {
                themeController.toggleTheme(value);
              },
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BantuanPage()),
              );
            },
            child: _menuTile(
              icon: Icons.help_outline,
              title: 'Bantuan & Dukungan',
              trailing:
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LegalPolicyPage()),
              );
            },
            child: _menuTile(
              icon: Icons.description_rounded,
              title: 'Legalitas & Privasi',
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Konfirmasi Keluar',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun EMERYS Anda?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: Text(
              'Keluar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            )
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
        onPressed: () => _showLogoutDialog(context),
        icon: Icon(
          Icons.logout,
          color: Theme.of(context).colorScheme.error,
          size: 28,
        ),

        label: Text(
          'Keluar',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 25,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
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
    return SizedBox(
      width: 48,
      height: 28,
      child: Transform.scale(
        scale: 0.7,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF2FB4A6),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD4DDE0),
        ),
      ),
    );
  }
}
