import 'dart:async';
import 'package:endurain/core/utils/platform_utils.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:injectable/injectable.dart';

@singleton
class BluetoothSensorService {
  // Standard BLE Service UUIDs
  static final Guid _heartRateService = Guid('180D');
  static final Guid _cscService = Guid('1816'); // Cycling Speed and Cadence

  // Standard BLE Characteristic UUIDs
  static final Guid _heartRateMeasurement = Guid('2A37');
  static final Guid _cscMeasurement = Guid('2A5B');

  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  final StreamController<int> _cadenceController =
      StreamController<int>.broadcast();

  Stream<int> get heartRate => _heartRateController.stream;
  Stream<int> get cadence => _cadenceController.stream;

  // Track connected devices to auto-reconnect or manage state
  final Map<String, BluetoothDevice> _connectedDevices = {};

  Future<void> init() async {
    // Check permissions
    if (await Permission.bluetoothScan.request().isGranted &&
        await Permission.bluetoothConnect.request().isGranted) {
      // Ready
    }
  }

  Future<void> startScan() async {
    // Check and request permissions first
    if (!await _checkPermissions()) {
      throw Exception('Bluetooth permissions not granted');
    }

    // Stop any existing scan first
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid('180D'), Guid('1816')], // Heart Rate, CSC
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true, // Required for BLE on older Android
      );
    } catch (e) {
      // Re-throw or handle specific BLE errors
      throw Exception('Failed to start BLE scan: $e');
    }
  }

  Future<bool> _checkPermissions() async {
    // If not Android, assume true for now (iOS handles permissions via plist)
    if (!PlatformUtils.isAndroid) return true;

    // Request permissions based on Android version logic handled by permission_handler
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if we have enough permissions to proceed
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    // Android 12+ needs Scan + Connect
    // Android < 12 needs Location
    // We return true if EITHER set is satisfied
    return (scanGranted && connectGranted) || locationGranted;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> connect(BluetoothDevice device) async {
    await device.connect();
    _connectedDevices[device.remoteId.str] = device;

    // Discover services
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == _heartRateService) {
        _subscribeToHeartRate(service);
      } else if (service.uuid == _cscService) {
        _subscribeToCSC(service);
      }
    }
  }

  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
    _connectedDevices.remove(device.remoteId.str);
  }

  void _subscribeToHeartRate(BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _heartRateMeasurement) {
        characteristic.setNotifyValue(true);
        characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            _parseHeartRate(value);
          }
        });
      }
    }
  }

  void _subscribeToCSC(BluetoothService service) {
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == _cscMeasurement) {
        characteristic.setNotifyValue(true);
        characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            _parseCSC(value);
          }
        });
      }
    }
  }

  void _parseHeartRate(List<int> value) {
    // Flags: 1st byte.
    // Bit 0: Value Format (0 = UINT8, 1 = UINT16)
    final flags = value[0];
    final isUint16 = (flags & 0x01) != 0;

    int hr;
    if (isUint16) {
      // Format is UINT16
      hr = value[1] + (value[2] << 8);
    } else {
      // Format is UINT8
      hr = value[1];
    }

    _heartRateController.add(hr);
  }

  void _parseCSC(List<int> value) {
    // Flags: 1st byte
    // Bit 0: Wheel Revolution Data Present
    // Bit 1: Crank Revolution Data Present
    final flags = value[0];
    final hasWheelData = (flags & 0x01) != 0;
    final hasCrankData = (flags & 0x02) != 0;

    int offset = 1;

    if (hasWheelData) {
      // Wheel Revolutions (UINT32) + Last Wheel Event Time (UINT16)
      // 4 + 2 = 6 bytes
      offset += 6;
    }

    if (hasCrankData) {
      if (value.length >= offset + 4) {
        // Crank Revolutions (UINT16)
        // Last Crank Event Time (UINT16)
        // We need to calculate RPM based on diffs, but for now let's just parse the raw values or simple diff if we stored state.
        // Implementing full RPM calc requires state.
        // For this MVP, let's just log or emit 0 if we don't have state logic yet.
        // Real implementation needs: rpm = (diff_crank / diff_time) * 1024 * 60

        // Placeholder:
        _cadenceController.add(0); // TODO: Implement stateful calculation
      }
    }
  }

  void dispose() {
    _heartRateController.close();
    _cadenceController.close();
  }
}
