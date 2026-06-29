class SensorData {
  final String deviceId;
  final int pressureLeft;
  final int pressureRight;
  final double accX;
  final double accY;
  final double accZ;
  final String status;
  final String receivedAt;

  SensorData({
    required this.deviceId,
    required this.pressureLeft,
    required this.pressureRight,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.status,
    required this.receivedAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      deviceId: json['device_id'] ?? '-',
      pressureLeft: (json['pressure_left'] ?? 0).toInt(),
      pressureRight: (json['pressure_right'] ?? 0).toInt(),
      accX: (json['acc_x'] ?? 0).toDouble(),
      accY: (json['acc_y'] ?? 0).toDouble(),
      accZ: (json['acc_z'] ?? 0).toDouble(),
      status: json['status'] ?? 'unknown',
      receivedAt: json['received_at'] ?? '-',
    );
  }
}