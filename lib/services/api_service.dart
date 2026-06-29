import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor.dart';

class ApiService {
  static const String baseUrl = 'https://expose-bakeshop-slicer.ngrok-free.dev';

  static Future<SensorData?> getLatestSensorData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SensorData.fromJson(data);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}