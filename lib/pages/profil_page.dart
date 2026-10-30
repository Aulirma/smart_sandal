import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/backend_api_service.dart';

class ProfilPage extends StatefulWidget {
  final VoidCallback onBackPressed;

  const ProfilPage({super.key, required this.onBackPressed});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final BackendApiService _api = BackendApiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasData = false;
  bool _isLoadingWali = true;

  String? _elderlyId;
  String? _deviceId;

  Map<String, dynamic>? _waliData;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _waliSubscription;

  final _namaController = TextEditingController();
  final _usiaController = TextEditingController();
  final _catatanController = TextEditingController();

  bool get _isDeviceConnected =>
      _deviceId != null && _deviceId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _waliSubscription?.cancel();

    _namaController.dispose();
    _usiaController.dispose();
    _catatanController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD PROFIL DARI FIRESTORE
  // Satu akun wali mengambil satu profil lansia yang terhubung.
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Pengguna belum login.');
      }

      final snapshot = await _firestore
          .collection('elderly_profiles')
          .where('waliIds', arrayContains: user.uid)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        final elderlyId = snapshot.docs.first.id;

        setState(() {
          _hasData = true;
          _elderlyId = elderlyId;
        });

        _listenToElderlyProfile(elderlyId);
      } else {
        setState(() {
          _hasData = false;
          _elderlyId = null;
          _deviceId = null;
          _waliData = null;
          _isLoadingWali = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil profil lansia: $e');

      if (mounted) {
        _showMessage('Gagal mengambil data profil: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // LISTENER PROFIL LANSIA
  // ============================================================

  void _listenToElderlyProfile(String elderlyId) {
    _profileSubscription?.cancel();

    debugPrint('[Firestore] Listen elderly_profiles/$elderlyId');

    _profileSubscription = _firestore
        .collection('elderly_profiles')
        .doc(elderlyId)
        .snapshots()
        .listen(
          (snapshot) {
        if (!snapshot.exists) {
          if (!mounted) return;

          setState(() {
            _hasData = false;
            _elderlyId = null;
            _deviceId = null;
            _waliData = null;
            _isLoadingWali = false;
          });

          return;
        }

        final data = snapshot.data();

        if (data == null || !mounted) return;

        final deviceId = data['deviceId']?.toString();
        final waliIds = List<dynamic>.from(data['waliIds'] ?? []);

        setState(() {
          _hasData = true;
          _elderlyId = snapshot.id;
          _deviceId = deviceId;

          _namaController.text = data['name']?.toString() ?? '';
          _usiaController.text = data['age']?.toString() ?? '';
          _catatanController.text =
              data['healthNote']?.toString() ?? '';
        });

        _listenToWali(waliIds);
      },
      onError: (error) {
        debugPrint('[Firestore] Error listener profil: $error');
      },
    );
  }

  // ============================================================
  // LISTENER KONTAK WALI DARI USERS
  // ============================================================

  void _listenToWali(List<dynamic> waliIds) {
    _waliSubscription?.cancel();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (waliIds.isEmpty) {
      if (!mounted) return;

      setState(() {
        _waliData = null;
        _isLoadingWali = false;
      });

      return;
    }

    final otherWaliIds = waliIds
        .map((id) => id.toString())
        .where((id) => id != currentUid)
        .toList();

    final targetWaliId = otherWaliIds.isNotEmpty
        ? otherWaliIds.first
        : waliIds.first.toString();

    if (!mounted) return;

    setState(() {
      _isLoadingWali = true;
    });

    _waliSubscription = _firestore
        .collection('users')
        .doc(targetWaliId)
        .snapshots()
        .listen(
          (snapshot) {
        if (!mounted) return;

        setState(() {
          _waliData = snapshot.exists ? snapshot.data() : null;
          _isLoadingWali = false;
        });
      },
      onError: (error) {
        debugPrint('[Firestore] Error listener wali: $error');

        if (!mounted) return;

        setState(() {
          _waliData = null;
          _isLoadingWali = false;
        });
      },
    );
  }

  // ============================================================
  // FORM TAMBAH / EDIT PROFIL
  // ============================================================

  void _showFormInput({bool isEdit = false}) {
    if (!isEdit) {
      _namaController.clear();
      _usiaController.clear();
      _catatanController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Edit Data Lansia' : 'Tambah Profil Lansia',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildFormTextField(
                      'Nama Lengkap',
                      _namaController,
                      'Masukkan nama lansia',
                    ),

                    const SizedBox(height: 16),

                    _buildFormTextField(
                      'Usia',
                      _usiaController,
                      'Contoh: 72',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 16),

                    _buildFormTextField(
                      'Catatan Kesehatan',
                      _catatanController,
                      'Masukkan diagnosa atau catatan medis',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                          setSheetState(() {});
                          await _saveProfile(
                            sheetContext,
                            setSheetState,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D8B94),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          isEdit
                              ? 'Simpan Perubahan'
                              : 'Simpan Profil',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SIMPAN PROFIL KE FIRESTORE
  // ============================================================

  Future<void> _saveProfile(
      BuildContext sheetContext,
      StateSetter setSheetState,
      ) async {
    if (_isSaving) return;

    final name = _namaController.text.trim();
    final ageText = _usiaController.text.trim();
    final healthNote = _catatanController.text.trim();

    if (name.isEmpty) {
      _showMessage('Nama lansia wajib diisi.');
      return;
    }

    if (ageText.isEmpty) {
      _showMessage('Usia lansia wajib diisi.');
      return;
    }

    final age = int.tryParse(ageText);

    if (age == null || age < 1 || age > 150) {
      _showMessage('Usia tidak valid.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    setState(() {
      _isSaving = true;
    });
    setSheetState(() {});

    try {
      if (_elderlyId == null) {
        // CEK DOKUMEN USER SEBELUM MEMBUAT PROFIL
        final userRef = _firestore.collection('users').doc(user.uid);
        final userSnapshot = await userRef.get();

        if (!userSnapshot.exists) {
          throw Exception(
            'Data akun wali tidak ditemukan di koleksi users.',
          );
        }

        // BUAT DOKUMEN PROFIL LANSIA
        final elderlyRef =
        _firestore.collection('elderly_profiles').doc();

        final batch = _firestore.batch();

        batch.set(elderlyRef, {
          'name': name,
          'age': age,
          'healthNote': healthNote,
          'createdAt': FieldValue.serverTimestamp(),
          'deviceId': '',
          'waliIds': [user.uid],
        });

        // HUBUNGKAN PROFIL KE AKUN WALI
        batch.update(userRef, {
          'elderlyIds': FieldValue.arrayUnion([elderlyRef.id]),
        });

        await batch.commit();

        if (!mounted || !sheetContext.mounted) return;

        setState(() {
          _hasData = true;
          _elderlyId = elderlyRef.id;
          _deviceId = '';
        });

        _listenToElderlyProfile(elderlyRef.id);

        Navigator.pop(sheetContext);

        _showMessage('Profil lansia berhasil ditambahkan ke database.');
      } else {
        // UPDATE PROFIL YANG SUDAH ADA
        await _firestore
            .collection('elderly_profiles')
            .doc(_elderlyId)
            .update({
          'name': name,
          'age': age,
          'healthNote': healthNote,
        });

        if (!mounted || !sheetContext.mounted) return;

        Navigator.pop(sheetContext);

        _showMessage('Profil lansia berhasil diperbarui.');
      }
    } catch (e) {
      debugPrint('[Firestore] Gagal menyimpan profil: $e');

      if (mounted) {
        _showMessage('Gagal menyimpan profil: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }

      if (sheetContext.mounted) {
        setSheetState(() {});
      }
    }
  }

  // ============================================================
  // DEVICE PAIRING
  // ============================================================

  Future<String?> _showDeviceIdDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Hubungkan Perangkat',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan Device ID yang tertera pada perangkat EMERYS.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),

              const SizedBox(height: 16),

              const Text(
                'Device ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Contoh: EMERYS_001',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0D8B94),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final deviceId = controller.text.trim();

                if (deviceId.isEmpty) return;

                Navigator.pop(dialogContext, deviceId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D8B94),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Lanjutkan'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _generatePairingCode() async {
    if (!_hasData) {
      _showMessage('Buat profil lansia terlebih dahulu.');
      return;
    }

    if (_isDeviceConnected) {
      _showMessage('Perangkat lansia sudah terhubung.');
      return;
    }

    final deviceId = await _showDeviceIdDialog();

    if (deviceId == null || deviceId.isEmpty) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _api.generateDevicePairing(
        deviceId: deviceId,
      );

      if (!mounted) return;

      Navigator.pop(context);

      final code = result['pairingCode']?.toString() ?? '';
      final expires = result['expiresInMinutes']?.toString() ?? '15';

      if (code.isEmpty) {
        _showMessage('Kode pairing tidak ditemukan.');
        return;
      }

      _showPairingCodeDialog(
        code: code,
        expiresInMinutes: expires,
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);
      _showMessage('Gagal membuat kode pairing: $e');
    }
  }

  void _showPairingCodeDialog({
    required String code,
    required String expiresInMinutes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Center(
            child: Text(
              'Kode Setup Perangkat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan kode berikut pada HP lansia.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D8B94)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFF0D8B94),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Kode berlaku selama $expiresInMinutes menit '
                    'dan hanya dapat digunakan satu kali.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8B94),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Selesai'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
        Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
            size: 24,
          ),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          'Profil Lansia',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: _hasData
            ? [
          IconButton(
            tooltip: 'Edit profil',
            onPressed: () => _showFormInput(isEdit: true),
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF0D8B94),
            ),
          ),
        ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasData
          ? _buildProfileContent()
          : _buildEmptyState(),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_ind_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 16),

            Text(
              'Belum Ada Profil Lansia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tambahkan profil lansia untuk mulai menggunakan EMERYS.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showFormInput(isEdit: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D8B94),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: const Text(
                  '+ Tambah Profil Lansia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE CONTENT
  // ============================================================

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DATA PROFIL
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D8B94)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF0D8B94),
                              size: 30,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _namaController.text,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Usia: ${_usiaController.text} tahun',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          GestureDetector(
                            onTap: () => _showFormInput(isEdit: true),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CATATAN KESEHATAN
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSectionHeader(
                        Icons.medical_services_outlined,
                        'Catatan Kesehatan',
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness ==
                              Brightness.dark
                              ? Colors.black12
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _catatanController.text.isNotEmpty
                              ? _catatanController.text
                              : 'Tidak ada catatan kesehatan',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),

                    Divider(
                      height: 48,
                      thickness: 1.2,
                      color: Theme.of(context).dividerColor,
                    ),

                    _buildDeviceSection(),

                    Divider(
                      height: 48,
                      thickness: 1.2,
                      color: Theme.of(context).dividerColor,
                    ),

                    _buildEmergencyContactSection(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                  _isDeviceConnected ? null : _generatePairingCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D8B94),
                    disabledBackgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: Text(
                    _isDeviceConnected
                        ? 'Perangkat Sudah Terhubung'
                        : 'Kelola Perangkat',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DEVICE SECTION
  // ============================================================

  Widget _buildDeviceSection() {
    if (!_isDeviceConnected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  Icons.bluetooth_disabled,
                  'Perangkat',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'BELUM TERHUBUNG',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 46,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Sandal pintar belum terhubung.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Hubungkan perangkat dengan menggunakan '
                        'kode setup pada HP lansia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _generatePairingCode,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D8B94),
                        side: const BorderSide(
                          color: Color(0xFF0D8B94),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Generate Kode Setup',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            Icons.bluetooth_connected,
            'Perangkat Terhubung',
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  'EMERYS Sandal Pintar',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Text(
                'Terhubung',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KONTAK DARURAT DARI USERS
  // ============================================================

  Widget _buildEmergencyContactSection() {
    final waliName = _waliData?['name']?.toString() ?? '';
    final waliPhone = _waliData?['phone']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            Icons.phone_android_outlined,
            'Kontak Darurat',
          ),

          const SizedBox(height: 16),

          if (_isLoadingWali)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_waliData == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 42,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Data wali belum tersedia',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Pastikan profil lansia sudah terhubung '
                        'dengan akun wali.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D8B94)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF0D8B94),
                      size: 26,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waliName.isNotEmpty
                              ? waliName
                              : 'Nama wali belum tersedia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          waliPhone.isNotEmpty
                              ? waliPhone
                              : 'Nomor telepon belum tersedia',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Wali Lansia',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D8B94),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF0D8B94),
                    size: 22,
                  ),
                ],
              ),
            ),

          // Jarak bawah supaya kartu tidak menempel ke tepi card utama
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0D8B94),
          size: 18,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildFormTextField(
      String label,
      TextEditingController controller,
      String hint, {
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 8),

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0D8B94),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}