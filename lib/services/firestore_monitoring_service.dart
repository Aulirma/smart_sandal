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

  // ============================================================
  // LANGKAH PER HARI (7 hari terakhir)
  // ============================================================

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Emit map {yyyy-MM-dd: jumlah langkah} untuk [days] hari terakhir.
  Stream<Map<String, int>> watchDailySteps(
      String deviceId, {
        int days = 7,
      }) {
    final cleanDeviceId = deviceId.trim();

    if (cleanDeviceId.isEmpty) {
      return Stream.value(<String, int>{});
    }

    final from = DateTime.now().subtract(Duration(days: days - 1));

    return _firestore
        .collection('device_telemetry')
        .doc(cleanDeviceId)
        .collection('daily_steps')
        .where('date', isGreaterThanOrEqualTo: dateKey(from))
        .snapshots()
        .map((snapshot) {
      final result = <String, int>{};

      for (final doc in snapshot.docs) {
        final steps = doc.data()['steps'];

        if (steps is num) {
          result[doc.id] = steps.toInt();
        }
      }

      return result;
    });
  }

  // ============================================================
  // PERINGATAN TERBARU (fall_events)
  // ============================================================

  /// Peringatan jatuh terbaru milik [elderlyId], terbaru di atas.
  /// Diurutkan di sisi aplikasi agar tidak butuh composite index.
  Stream<List<Map<String, dynamic>>> watchRecentFallEvents(
      String elderlyId, {
        int limit = 5,
      }) {
    final cleanId = elderlyId.trim();

    if (cleanId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('fall_events')
        .where('elderlyId', isEqualTo: cleanId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
          .toList();

      DateTime timeOf(Map<String, dynamic> e) {
        final t = e['timestamp'];
        return t is Timestamp
            ? t.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
      }

      events.sort((a, b) => timeOf(b).compareTo(timeOf(a)));

      return events.take(limit).toList();
    });
  }
}