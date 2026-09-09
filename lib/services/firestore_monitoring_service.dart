import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreMonitoringService {
  FirestoreMonitoringService._();

  static final FirestoreMonitoringService instance =
  FirestoreMonitoringService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // REALTIME LATEST TELEMETRY
  // ============================================================

  Stream<Map<String, dynamic>?> watchLatestTelemetry(
      String deviceId,
      ) {
    final cleanDeviceId = deviceId.trim();

    if (cleanDeviceId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('device_telemetry')
        .doc(cleanDeviceId)
        .collection('latest')
        .doc('current')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return Map<String, dynamic>.from(data);
    });
  }
}