class SensorData {
  final String deviceId;

  // Accelerometer
  final double accX;
  final double accY;
  final double accZ;

  // Gyroscope
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  // GPS
  final double latitude;
  final double longitude;

  // Status perangkat
  final String status;
  final int battery;

  // Waktu diterima
  final DateTime receivedAt;

  SensorData({
    required this.deviceId,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.battery,
    required this.receivedAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      deviceId: json['id'] ?? '-',

      accX: (json['ax'] ?? 0).toDouble(),
      accY: (json['ay'] ?? 0).toDouble(),
      accZ: (json['az'] ?? 0).toDouble(),

      gyroX: (json['gx'] ?? 0).toDouble(),
      gyroY: (json['gy'] ?? 0).toDouble(),
      gyroZ: (json['gz'] ?? 0).toDouble(),

      latitude: (json['lat'] ?? 0).toDouble(),
      longitude: (json['lon'] ?? 0).toDouble(),

      status: json['st'] ?? 'unknown',

      battery: (json['bat'] ?? 100).toInt(),

      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['ts'] ?? 0).toInt(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,

      'acc_x': accX,
      'acc_y': accY,
      'acc_z': accZ,

      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,

      'latitude': latitude,
      'longitude': longitude,

      'status': status,

      'battery': battery,

      'received_at': receivedAt.toIso8601String(),
    };
  }
}