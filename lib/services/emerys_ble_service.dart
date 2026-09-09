import 'dart:async';
import 'dart:convert';
import 'backend_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
}

class EmerysBleService {
  EmerysBleService._();

  static final EmerysBleService instance =
  EmerysBleService._();

  // ============================================================
  // ESP32 BLE CONFIG
  // ============================================================

  static const String targetDeviceName =
      "EMERYS Smart";

  static final Guid serviceUuid = Guid(
    "12345678-1234-1234-1234-123456789000",
  );

  static final Guid characteristicUuid = Guid(
    "12345678-1234-1234-1234-123456789001",
  );

  // ============================================================
  // DEVICE
  // ============================================================

  BluetoothDevice? _device;

  BluetoothCharacteristic? _characteristic;

  // ============================================================
  // TELEMETRY BUFFER
  // ============================================================

  static const int telemetryBufferSize = 50;

  // ESP32 saat ini mengirim BLE sekitar 10 Hz.
  static const int telemetrySampleRate = 10;

  final List<Map<String, dynamic>>
  _telemetryBuffer = [];

  int? _chunkSequence;
  int _expectedChunks = 0;

  final Map<int, String> _receivedChunks = {};

  bool _isUploadingTelemetry = false;

  BluetoothDevice? get connectedDevice =>
      _device;

  bool get isConnected =>
      _device != null &&
          _characteristic != null;

  // ============================================================
  // STATUS STREAM
  // ============================================================

  final StreamController<BleConnectionStatus>
  _statusController =
  StreamController<BleConnectionStatus>.broadcast();

  Stream<BleConnectionStatus> get statusStream =>
      _statusController.stream;

  BleConnectionStatus _connectionStatus =
      BleConnectionStatus.disconnected;

  BleConnectionStatus get connectionStatus =>
      _connectionStatus;

  void _updateConnectionStatus(
      BleConnectionStatus status,
      ) {
    _connectionStatus = status;

    if (!_statusController.isClosed) {
      _statusController.add(status);
    }

    debugPrint(
      'BLE STATUS: $status',
    );
  }

  // ============================================================
  // SENSOR DATA STREAM
  // ============================================================

  final StreamController<Map<String, dynamic>>
  _sensorDataController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>>
  get sensorDataStream =>
      _sensorDataController.stream;

  // SCAN BLE DEVICES
  Future<List<ScanResult>> scanDevices() async {
    final List<ScanResult> devices = [];

    StreamSubscription<List<ScanResult>>?
    subscription;

    try {
      _updateConnectionStatus(
        BleConnectionStatus.scanning,
      );

      debugPrint(
        "================================",
      );

      debugPrint(
        "BLE SCAN START",
      );

      debugPrint(
        "Target: $targetDeviceName",
      );

      debugPrint(
        "================================",
      );

      final adapterState =
      await FlutterBluePlus.adapterState.first;

      debugPrint(
        "Bluetooth state: $adapterState",
      );

      if (adapterState !=
          BluetoothAdapterState.on) {
        throw Exception(
          "Bluetooth belum aktif. "
              "Silakan aktifkan Bluetooth.",
        );
      }

      subscription =
          FlutterBluePlus.scanResults.listen(
                (results) {

              for (final result in results) {

                final device =
                    result.device;

                final platformName =
                    device.platformName;

                final advertisementName =
                    result.advertisementData.advName;

                final serviceUuids =
                    result.advertisementData.serviceUuids;

                final name =
                platformName.isNotEmpty
                    ? platformName
                    : advertisementName;

                debugPrint(
                  "BLE SCAN RESULT: "
                      "name='$name' "
                      "platformName='$platformName' "
                      "advName='$advertisementName' "
                      "serviceUuids=$serviceUuids "
                      "id=${device.remoteId}",
                );

                // if (name != targetDeviceName) {
                //   continue;
                // }

                final alreadyExists =
                devices.any(
                      (item) =>
                  item.device.remoteId ==
                      device.remoteId,
                );

                if (!alreadyExists) {

                  devices.add(result);

                  debugPrint(
                    "================================",
                  );

                  debugPrint(
                    "BLE FOUND EMERYS!",
                  );

                  debugPrint(
                    "Name: $name",
                  );

                  debugPrint(
                    "ID: ${device.remoteId}",
                  );

                  debugPrint(
                    "RSSI: ${result.rssi}",
                  );

                  debugPrint(
                    "================================",
                  );
                }
              }
            },
          );

      await FlutterBluePlus.startScan(
        timeout: const Duration(
          seconds: 5,
        ),
      );

      // Beri waktu hasil terakhir masuk ke listener
      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      await subscription.cancel();

      subscription = null;

      await FlutterBluePlus.stopScan();

      debugPrint(
        "BLE SCAN FINISHED: "
            "${devices.length} EMERYS device(s)",
      );

      _updateConnectionStatus(
        BleConnectionStatus.disconnected,
      );

      return devices;

    } catch (e) {

      await subscription?.cancel();

      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      _updateConnectionStatus(
        BleConnectionStatus.disconnected,
      );

      debugPrint(
        "BLE SCAN ERROR: $e",
      );

      rethrow;
    }
  }

  // ============================================================
  // CONNECT TO DEVICE
  // ============================================================

  Future<bool> connectToDevice(
      BluetoothDevice device,
      ) async {

    try {

      _updateConnectionStatus(
        BleConnectionStatus.connecting,
      );

      debugPrint(
        "================================",
      );

      debugPrint(
        "CONNECTING TO EMERYS",
      );

      debugPrint(
        "Name: ${device.platformName}",
      );

      debugPrint(
        "ID: ${device.remoteId}",
      );

      debugPrint(
        "================================",
      );

      // --------------------------------------------------------
      // PUTUSKAN DEVICE LAMA
      // --------------------------------------------------------

      if (_device != null &&
          _device!.remoteId !=
              device.remoteId) {

        try {
          await _device!.disconnect();
        } catch (_) {}
      }

      // --------------------------------------------------------
      // CONNECT
      // --------------------------------------------------------

      await device.connect(
        timeout: const Duration(
          seconds: 10,
        ),
      );

      debugPrint(
        "BLE CONNECTED!",
      );

      _device = device;

      // --------------------------------------------------------
      // DISCOVER SERVICES
      // --------------------------------------------------------

      debugPrint(
        "BLE: Discovering services...",
      );

      final services =
      await device.discoverServices();

      debugPrint(
        "BLE: ${services.length} services found",
      );

      // --------------------------------------------------------
      // CARI SERVICE EMERYS
      // --------------------------------------------------------

      BluetoothService? emerysService;

      for (final service in services) {

        debugPrint(
          "BLE SERVICE FOUND: "
              "${service.uuid}",
        );

        if (service.uuid ==
            serviceUuid) {

          emerysService =
              service;

          break;
        }
      }

      if (emerysService == null) {

        debugPrint(
          "BLE ERROR: EMERYS service "
              "tidak ditemukan.",
        );

        await device.disconnect();

        _device = null;

        _updateConnectionStatus(
          BleConnectionStatus.disconnected,
        );

        return false;
      }

      debugPrint(
        "BLE: EMERYS SERVICE FOUND",
      );

      // --------------------------------------------------------
      // CARI CHARACTERISTIC
      // --------------------------------------------------------

      BluetoothCharacteristic?
      characteristic;

      for (final c
      in emerysService.characteristics) {

        debugPrint(
          "BLE CHARACTERISTIC FOUND: "
              "${c.uuid}",
        );

        if (c.uuid ==
            characteristicUuid) {

          characteristic = c;

          break;
        }
      }

      if (characteristic == null) {

        debugPrint(
          "BLE ERROR: EMERYS characteristic "
              "tidak ditemukan.",
        );

        await device.disconnect();

        _device = null;

        _updateConnectionStatus(
          BleConnectionStatus.disconnected,
        );

        return false;
      }

      _characteristic =
          characteristic;

      debugPrint(
        "BLE: EMERYS CHARACTERISTIC FOUND",
      );

      // --------------------------------------------------------
      // SUBSCRIBE NOTIFICATION
      // --------------------------------------------------------

      debugPrint(
        "BLE: Enabling notifications...",
      );

      await characteristic
          .setNotifyValue(true);

      debugPrint(
        "BLE: Notifications ENABLED",
      );

      // --------------------------------------------------------
      // LISTEN DATA BLE
      // --------------------------------------------------------

      characteristic
          .onValueReceived
          .listen(
        _onBleDataReceived,
      );

      // --------------------------------------------------------
      // CONNECTION STATE
      // --------------------------------------------------------

      device.connectionState.listen(
            (state) {

          debugPrint(
            "BLE CONNECTION STATE: $state",
          );

          if (state ==
              BluetoothConnectionState
                  .disconnected) {

            if (_device?.remoteId ==
                device.remoteId) {

              _device = null;
              _characteristic = null;

              _updateConnectionStatus(
                BleConnectionStatus.disconnected,
              );
            }
          }
        },
      );

      _updateConnectionStatus(
        BleConnectionStatus.connected,
      );

      debugPrint(
        "================================",
      );

      debugPrint(
        "EMERYS BLE READY",
      );

      debugPrint(
        "Waiting for sensor data...",
      );

      debugPrint(
        "================================",
      );

      return true;

    } catch (e) {

      debugPrint(
        "BLE CONNECTION ERROR: $e",
      );

      _device = null;
      _characteristic = null;

      _updateConnectionStatus(
        BleConnectionStatus.disconnected,
      );

      return false;
    }
  }

  // RECEIVE BLE DATA
  void _onBleDataReceived(
      List<int> value,
      ) {
    if (value.isEmpty) {
      return;
    }

    try {
      final raw = utf8.decode(
        value,
        allowMalformed: true,
      );

      debugPrint(
        '================================',
      );

      debugPrint(
        'BLE RX CHUNK:',
      );

      debugPrint(raw);

      debugPrint(
        '================================',
      );

      _handleBleChunk(raw);

    } catch (e) {

      debugPrint(
        'BLE RX ERROR: $e',
      );
    }
  }

  // HANDLE BLE JSON CHUNK
  void _handleBleChunk(
      String packet,
      ) {

    if (!packet.startsWith('@')) {

      debugPrint(
        'BLE PACKET DIABAIKAN: '
            'bukan chunk protocol.',
      );

      return;
    }

    final firstColon =
    packet.indexOf(':');

    final secondColon =
    packet.indexOf(
      ':',
      firstColon + 1,
    );

    final thirdColon =
    packet.indexOf(
      ':',
      secondColon + 1,
    );

    if (firstColon == -1 ||
        secondColon == -1 ||
        thirdColon == -1) {
      debugPrint(
        'BLE CHUNK HEADER TIDAK VALID:',
      );
      debugPrint(packet);
      return;
    }

    final sequenceText =
    packet.substring(
      1,
      firstColon,
    );

    final chunkIndexText =
    packet.substring(
      firstColon + 1,
      secondColon,
    );

    final totalChunksText =
    packet.substring(
      secondColon + 1,
      thirdColon,
    );

    final payload =
    packet.substring(
      thirdColon + 1,
    );

    final sequence =
    int.tryParse(
      sequenceText,
    );

    final chunkIndex =
    int.tryParse(
      chunkIndexText,
    );

    final totalChunks =
    int.tryParse(
      totalChunksText,
    );

    if (sequence == null ||
        chunkIndex == null ||
        totalChunks == null) {
      debugPrint(
        'BLE CHUNK METADATA INVALID:',
      );
      debugPrint(packet);
      return;
    }
    if (totalChunks <= 0 ||
        chunkIndex < 0 ||
        chunkIndex >= totalChunks) {
      debugPrint(
        'BLE CHUNK INDEX INVALID:',
      );
      debugPrint(packet);
      return;
    }

    if (_chunkSequence != sequence) {
      _chunkSequence =
          sequence;
      _expectedChunks =
          totalChunks;
      _receivedChunks.clear();
      debugPrint(
        'BLE CHUNK START: '
            'sequence=$sequence '
            'total=$totalChunks',
      );
    }
    if (_expectedChunks !=
        totalChunks) {
      debugPrint(
        'BLE CHUNK TOTAL MISMATCH: '
            'expected=$_expectedChunks '
            'received=$totalChunks',
      );

      return;
    }
    _receivedChunks[
    chunkIndex] = payload;

    debugPrint(
      'BLE CHUNK RECEIVED: '
          '${chunkIndex + 1}/$_expectedChunks '
          'sequence=$sequence',
    );

    if (_receivedChunks.length <
        _expectedChunks) {

      return;
    }
    final buffer =
    StringBuffer();
    for (
    int i = 0;
    i < _expectedChunks;
    i++
    ) {

      final chunk =
      _receivedChunks[i];
      if (chunk == null) {
        debugPrint(
          'BLE CHUNK MISSING: $i',
        );
        return;
      }
      buffer.write(
        chunk,
      );
    }
    final completeJson =
    buffer.toString();
    debugPrint(
      '================================',
    );
    debugPrint(
      'BLE JSON REASSEMBLED',
    );
    debugPrint(
      completeJson,
    );
    debugPrint(
      '================================',
    );
    // Reset chunk state
    _receivedChunks.clear();
    _chunkSequence = null;
    _expectedChunks = 0;
    _handleCompleteJson(
      completeJson,
    );
  }

// HANDLE COMPLETE JSON
  void _handleCompleteJson(
      String raw,
      ) {
    try {
      final decoded =
      jsonDecode(raw);

      debugPrint(
        'BLE RX JSON BERHASIL',
      );

      debugPrint(
        'deviceId: ${decoded['deviceId']}',
      );

      debugPrint(
        'sequence: ${decoded['sequence']}',
      );
      if (!_sensorDataController.isClosed) {
        _sensorDataController.add(
          decoded,
        );
      }
      // Masukkan ke telemetry buffer
      _addTelemetrySample(
        decoded,
      );
    } catch (e) {
      debugPrint(
        'BLE JSON PARSE ERROR: $e',
      );
      debugPrint(
        'RAW COMPLETE JSON:',
      );
      debugPrint(raw);
    }
  }

  // ADD SAMPLE TO TELEMETRY BUFFER
  void _addTelemetrySample(
      Map<String, dynamic> sample,
      ) {

    final deviceId =
    sample['deviceId']?.toString();

    if (deviceId == null ||
        deviceId.isEmpty) {

      debugPrint(
        'TELEMETRY BUFFER: '
            'deviceId tidak ditemukan.',
      );

      return;
    }

    _telemetryBuffer.add(
      sample,
    );

    debugPrint(
      'TELEMETRY BUFFER: '
          '${_telemetryBuffer.length}/'
          '$telemetryBufferSize',
    );

    // ----------------------------------------------------------
    // Kalau sudah 50 sample
    // ----------------------------------------------------------

    if (_telemetryBuffer.length >=
        telemetryBufferSize) {

      _uploadTelemetryWindow();
    }
  }

  // ============================================================
  // BUILD TELEMETRY WINDOW
  // ============================================================

  Map<String, dynamic>
  _buildTelemetryWindow(
      List<Map<String, dynamic>> samples,
      ) {

    final first =
        samples.first;

    final last =
        samples.last;

    // ----------------------------------------------------------
    // Helper untuk mengambil array channel sensor
    // ----------------------------------------------------------

    List<dynamic> getChannel(
        String sensor,
        String side,
        String field,
        ) {

      return samples.map(
            (sample) {

          final sensorData =
          sample[sensor];

          if (sensorData is! Map) {
            return null;
          }

          final sideData =
          sensorData[side];

          if (sideData is! Map) {
            return null;
          }

          return sideData[field];
        },
      ).toList();
    }

    // ----------------------------------------------------------
    // IMU LEFT
    // ----------------------------------------------------------

    final imuLeft = {
      'ax': getChannel(
        'imu',
        'left',
        'ax',
      ),

      'ay': getChannel(
        'imu',
        'left',
        'ay',
      ),

      'az': getChannel(
        'imu',
        'left',
        'az',
      ),

      'gx': getChannel(
        'imu',
        'left',
        'gx',
      ),

      'gy': getChannel(
        'imu',
        'left',
        'gy',
      ),

      'gz': getChannel(
        'imu',
        'left',
        'gz',
      ),
    };

    // ----------------------------------------------------------
    // IMU RIGHT
    // ----------------------------------------------------------

    final imuRight = {
      'ax': getChannel(
        'imu',
        'right',
        'ax',
      ),

      'ay': getChannel(
        'imu',
        'right',
        'ay',
      ),

      'az': getChannel(
        'imu',
        'right',
        'az',
      ),

      'gx': getChannel(
        'imu',
        'right',
        'gx',
      ),

      'gy': getChannel(
        'imu',
        'right',
        'gy',
      ),

      'gz': getChannel(
        'imu',
        'right',
        'gz',
      ),
    };

    // ----------------------------------------------------------
    // FSR LEFT
    // ----------------------------------------------------------

    final fsrLeft = {
      'rfront': getChannel(
        'fsr',
        'left',
        'rfront',
      ),

      'rback': getChannel(
        'fsr',
        'left',
        'rback',
      ),

      'lfront': getChannel(
        'fsr',
        'left',
        'lfront',
      ),

      'lback': getChannel(
        'fsr',
        'left',
        'lback',
      ),
    };

    // ----------------------------------------------------------
    // FSR RIGHT
    // ----------------------------------------------------------

    final fsrRight = {
      'rfront': getChannel(
        'fsr',
        'right',
        'rfront',
      ),

      'rback': getChannel(
        'fsr',
        'right',
        'rback',
      ),

      'lfront': getChannel(
        'fsr',
        'right',
        'lfront',
      ),

      'lback': getChannel(
        'fsr',
        'right',
        'lback',
      ),
    };

    // ----------------------------------------------------------
    // GPS
    //
    // Karena database hanya menyimpan satu koordinat final,
    // gunakan GPS terakhir yang tersedia dalam window.
    // ----------------------------------------------------------

    Map<String, dynamic>? latestGps;

    for (final sample in samples.reversed) {

      final gps =
      sample['gps'];

      if (gps is Map) {

        final latitude =
        gps['latitude'];

        final longitude =
        gps['longitude'];

        if (latitude != null &&
            longitude != null) {

          latestGps = {
            'latitude': latitude,
            'longitude': longitude,
          };

          break;
        }
      }
    }

    // ----------------------------------------------------------
    // BATTERY
    //
    // Ambil battery terakhir jika nanti sudah tersedia.
    // ----------------------------------------------------------

    Map<String, dynamic>? latestBattery;

    for (final sample in samples.reversed) {

      final battery =
      sample['battery'];

      if (battery is Map) {

        latestBattery = {
          'left': battery['left'],
          'right': battery['right'],
        };

        break;
      }
    }

    // ----------------------------------------------------------
    // WINDOW
    // ----------------------------------------------------------

    return {
      'sampleRate': telemetrySampleRate,

      'sampleCount': samples.length,

      'startTimestamp':
      first['timestamp'],

      'endTimestamp':
      last['timestamp'],

      'sequenceStart':
      first['sequence'],

      'sequenceEnd':
      last['sequence'],

      'imu': {
        'left': imuLeft,
        'right': imuRight,
      },

      'fsr': {
        'left': fsrLeft,
        'right': fsrRight,
      },

      'gps': latestGps,

      'battery': latestBattery,
    };
  }

  // ============================================================
  // GET LATEST TINYML
  // ============================================================

  Map<String, dynamic>?
  _getLatestTinyML(
      List<Map<String, dynamic>> samples,
      ) {

    for (final sample in samples.reversed) {

      final tinyml =
      sample['tinyml'];

      if (tinyml is Map) {

        return {
          'activity':
          tinyml['activity'],

          'stability':
          tinyml['stability'],

          'fallRisk':
          tinyml['fallRisk'],

          'confidence':
          tinyml['confidence'],

          'modelVersion':
          tinyml['modelVersion'],
        };
      }
    }

    return null;
  }

  // ============================================================
  // UPLOAD TELEMETRY WINDOW
  // ============================================================

  Future<void>
  _uploadTelemetryWindow() async {

    // Jangan melakukan upload ganda
    if (_isUploadingTelemetry) {
      return;
    }

    if (_telemetryBuffer.length <
        telemetryBufferSize) {
      return;
    }

    // ----------------------------------------------------------
    // Ambil tepat 50 sample
    // ----------------------------------------------------------

    final samples =
    List<Map<String, dynamic>>.from(
      _telemetryBuffer.take(
        telemetryBufferSize,
      ),
    );

    // Hapus 50 sample yang akan dikirim
    _telemetryBuffer.removeRange(
      0,
      telemetryBufferSize,
    );

    _isUploadingTelemetry = true;

    try {

      final first =
          samples.first;

      final deviceId =
      first['deviceId']?.toString();

      if (deviceId == null ||
          deviceId.isEmpty) {

        throw Exception(
          'deviceId tidak ditemukan '
              'pada telemetry window.',
        );
      }

      // --------------------------------------------------------
      // Build window
      // --------------------------------------------------------

      final window =
      _buildTelemetryWindow(
        samples,
      );

      // --------------------------------------------------------
      // TinyML
      // --------------------------------------------------------

      final tinyml =
      _getLatestTinyML(
        samples,
      );

      debugPrint(
        '================================',
      );

      debugPrint(
        'TELEMETRY UPLOAD START',
      );

      debugPrint(
        'Device : $deviceId',
      );

      debugPrint(
        'Samples: ${samples.length}',
      );

      debugPrint(
        'Sequence: '
            '${samples.first['sequence']}'
            ' - '
            '${samples.last['sequence']}',
      );

      // --------------------------------------------------------
      // POST BACKEND
      // --------------------------------------------------------

      final result =
      await BackendApiService()
          .sendTelemetry(
        deviceId: deviceId,
        window: window,
        tinyml: tinyml,
      );

      debugPrint(
        'TELEMETRY UPLOAD SUCCESS',
      );

      debugPrint(
        'Window ID: '
            '${result['windowId']}',
      );

      debugPrint(
        '================================',
      );

    } catch (e) {

      debugPrint(
        'TELEMETRY UPLOAD ERROR: $e',
      );

      // --------------------------------------------------------
      // Untuk tahap testing:
      // jangan memasukkan kembali sample ke buffer.
      //
      // Nanti kalau pipeline sudah stabil, kita bisa tambahkan
      // retry mechanism.
      // --------------------------------------------------------

    } finally {

      _isUploadingTelemetry = false;
    }
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {

    try {

      if (_device != null) {

        debugPrint(
          "Disconnecting "
              "${_device!.platformName}",
        );

        await _device!.disconnect();
      }

    } catch (e) {

      debugPrint(
        "BLE DISCONNECT ERROR: $e",
      );
    }

    _device = null;
    _characteristic = null;
    _telemetryBuffer.clear();
    _isUploadingTelemetry = false;
    _chunkSequence = null;
    _expectedChunks = 0;
    _receivedChunks.clear();

    _updateConnectionStatus(
      BleConnectionStatus.disconnected,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {

    _statusController.close();

    _sensorDataController.close();
  }
}