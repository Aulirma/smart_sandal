import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class BackendApiService {
  static const String baseUrl =
      'https://irmaaulia.pythonanywhere.com';

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    return user.getIdToken();
  }

  // ============================================================
  // PROFIL LANSIA
  // ============================================================

  /// Mengambil profil lansia milik wali yang sedang login.
  Future<Map<String, dynamic>> getMyElderlyProfile() async {
    final token = await _getIdToken();

    if (token == null) {
      throw Exception('Belum login.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/my-elderly-profile'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Gagal mengambil profil lansia.',
      );
    }

    return data;
  }

  /// Membuat PROFIL lansia saja.
  ///
  /// Belum membuat:
  /// - akun elderly_device
  /// - pairing code
  /// - deviceId
  Future<Map<String, dynamic>> createElderlyProfile({
    required String name,
    required int age,
    String healthNote = '',
  }) async {
    final token = await _getIdToken();

    if (token == null) {
      throw Exception('Belum login.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/create-elderly-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'age': age,
        'healthNote': healthNote,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Gagal membuat profil lansia.',
      );
    }

    return data;
  }

  // ============================================================
  // DEVICE / PAIRING
  // ============================================================

  /// Membuat akun elderly_device dan pairing code.
  ///
  /// Dipanggil ketika wali memilih:
  /// Profil Lansia -> Kelola Perangkat -> Generate Kode
  Future<Map<String, dynamic>> generateDevicePairing({
    required String deviceId,
  }) async {
    final token = await _getIdToken();

    if (token == null) {
      throw Exception('Belum login.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/generate-device-pairing'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'deviceId': deviceId,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Gagal membuat kode pairing.',
      );
    }

    return data;
  }

  /// Dipanggil dari HP lansia untuk menukarkan pairing code.
  Future<Map<String, dynamic>> redeemPairingCode(
      String code,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/redeem-pairing-code'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Kode tidak valid.',
      );
    }

    return data;
  }

  // ============================================================
  // FALL EVENT
  // ============================================================

  Future<void> sendFallEvent({
    required String severity,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _getIdToken();

    if (token == null) {
      throw Exception('Belum login.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/fall-event'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'severity': severity,
        if (latitude != null)
          'latitude': latitude,
        if (longitude != null)
          'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);

      throw Exception(
        data['detail'] ??
            'Gagal mengirim peringatan.',
      );
    }
  }

  // ============================================================
  // TELEMETRY
  // ============================================================

  /// Mengirim telemetry window dari HP Lansia ke backend.
  ///
  /// Data sudah dikumpulkan oleh EmerysBleService
  /// sebanyak 50 sample sebelum method ini dipanggil.
  Future<Map<String, dynamic>> sendTelemetry({
    required String deviceId,
    required Map<String, dynamic> window,
    Map<String, dynamic>? tinyml,
  }) async {
    final token = await _getIdToken();

    if (token == null) {
      throw Exception('Belum login.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/telemetry'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'deviceId': deviceId,
        'window': window,
        if (tinyml != null)
          'tinyml': tinyml,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ??
            'Gagal mengirim telemetry.',
      );
    }

    return data;
  }

}