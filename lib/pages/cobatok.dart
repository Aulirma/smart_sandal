import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor.dart';
import '../services/api_service.dart';

class SensorMonitoringPage extends StatefulWidget {
  const SensorMonitoringPage({super.key});

  @override
  State<SensorMonitoringPage> createState() => _SensorMonitoringPageState();
}

class _SensorMonitoringPageState extends State<SensorMonitoringPage> {
  SensorData? sensorData;
  Timer? timer;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      fetchData();
    });
  }

  Future<void> fetchData() async {
    final data = await ApiService.getLatestSensorData();

    if (!mounted) return;

    setState(() {
      sensorData = data;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (sensorData == null) {
      return const Scaffold(
        body: Center(child: Text('Gagal mengambil data sensor')),
      );
    }

    final data = sensorData!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring EMERYS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device ID: ${data.deviceId}'),
            Text('Pressure Left: ${data.pressureLeft}'),
            Text('Pressure Right: ${data.pressureRight}'),
            Text('Acc X: ${data.accX}'),
            Text('Acc Y: ${data.accY}'),
            Text('Acc Z: ${data.accZ}'),
            Text('Status: ${data.status}'),
            Text('Received At: ${data.receivedAt}'),
          ],
        ),
      ),
    );
  }
}