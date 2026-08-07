import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/sensor.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
}

class EmerysBleService {
  EmerysBleService._();

  static final EmerysBleService instance = EmerysBleService._();

  BleConnectionStatus _connectionStatus =
      BleConnectionStatus.disconnected;

  BleConnectionStatus get connectionStatus =>
      _connectionStatus;

  static const String targetDeviceName = "EMERYS_001";

  static final Guid serviceUuid = Guid(
    "6E400001-B5A3-F393-E0A9-E50E24DCCA9E",
  );

  static final Guid characteristicUuid = Guid(
    "6E400003-B5A3-F393-E0A9-E50E24DCCA9E",
  );

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  SensorData? _latestData;
  SensorData? get latestData => _latestData;

  final StreamController<SensorData> _sensorController =
  StreamController.broadcast();

  Stream<SensorData> get sensorStream => _sensorController.stream;

  bool get isConnected =>
      _connectionStatus == BleConnectionStatus.connected;

  bool _isReconnecting = false;

  Future<void> scanAndConnect() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _updateConnectionStatus(
      BleConnectionStatus.scanning,
    );
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
            (results) async {
      for (final result in results) {
        debugPrint(
          "FOUND : ${result.device.platformName}",
        );
        if (result.device.platformName == targetDeviceName) {
          await FlutterBluePlus.stopScan();
          await _scanSubscription?.cancel();
          _scanSubscription = null;
          _device = result.device;
          _updateConnectionStatus(
            BleConnectionStatus.connecting,
          );
          await _connect();
          break;
        }
      }
    });
  }

  Future<void> _connect() async {
    if (_device == null) return;
    try {
      await _device!.connect();
    }
    catch (_) {
      await reconnect();
    }

    final services = await _device!.discoverServices();

    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            _characteristic = characteristic;

            await characteristic.setNotifyValue(true);

            await _notifySubscription?.cancel();
            _notifySubscription =
                characteristic.lastValueStream.listen(_onReceive);
            _updateConnectionStatus(
              BleConnectionStatus.connected,
            );

            return;
          }
        }
      }
    }
  }

  void _onReceive(List<int> value) {
    try {
      final jsonString = utf8.decode(value);

      final jsonMap = jsonDecode(jsonString);

      final sensor = SensorData.fromJson(jsonMap);
      _latestData = sensor;
      if (!_sensorController.isClosed) {
        _sensorController.add(sensor);
      }
    } catch (e) {
      debugPrint(
        "BLE Decode Error : $e",
      );
    }
  }

  Future<void> disconnect() async {

    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await FlutterBluePlus.stopScan();
    await _device?.disconnect();
    _device = null;
    _characteristic = null;
    _updateConnectionStatus(
      BleConnectionStatus.disconnected,
    );
  }

  Future<void> reconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    await disconnect();
    await Future.delayed(
      const Duration(seconds: 2),
    );
    await scanAndConnect();
    _isReconnecting = false;
  }

  void _updateConnectionStatus(BleConnectionStatus status) {
    _connectionStatus = status;
  }

  Future<void> dispose() async {
    await disconnect();
    await _sensorController.close();
  }
}