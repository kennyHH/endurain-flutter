import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:endurain/core/services/bluetooth_sensor_service.dart';
import 'package:endurain/core/theme/endurain_design_system.dart';

class SensorSettingsScreen extends StatefulWidget {
  const SensorSettingsScreen({super.key, required this.bluetoothService});

  final BluetoothSensorService bluetoothService;

  @override
  State<SensorSettingsScreen> createState() => _SensorSettingsScreenState();
}

class _SensorSettingsScreenState extends State<SensorSettingsScreen> {
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];

  @override
  void initState() {
    super.initState();
    // Listen to scan results
    widget.bluetoothService.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await widget.bluetoothService.stopScan();
      setState(() {
        _isScanning = false;
      });
    } else {
      setState(() {
        _isScanning = true;
        _scanResults = []; // Clear previous results
      });
      await widget.bluetoothService.startScan();
      // Scan usually stops automatically after timeout, but we can manage UI state
      // Listener for isScanning state would be better if exposed,
      // but for now let's assume manual stop or timeout.
      // Ideally, listen to FlutterBluePlus.isScanning
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensors & Devices'), // TODO: Localize
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(EndurainSpacing.md),
              child: Text(
                'Manage your Heart Rate Monitors and Speed/Cadence sensors.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EndurainSpacing.md,
              ),
              child: FilledButton.icon(
                onPressed: _toggleScan,
                icon: Icon(_isScanning ? Icons.stop : Icons.search),
                label: Text(_isScanning ? 'Stop Scanning' : 'Scan for Devices'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(top: EndurainSpacing.md),
          ),

          if (_scanResults.isEmpty && !_isScanning)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No devices found. Tap Scan to start.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final result = _scanResults[index];
                final device = result.device;
                // final isConnected = device.isConnected; // Not directly exposed, need stream

                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(
                    device.platformName.isNotEmpty
                        ? device.platformName
                        : 'Unknown Device',
                  ),
                  subtitle: Text(device.remoteId.str),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      // Connect logic
                      widget.bluetoothService.connect(device);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Connecting to ${device.platformName}...',
                          ),
                        ),
                      );
                    },
                    child: const Text('Connect'),
                  ),
                );
              }, childCount: _scanResults.length),
            ),
        ],
      ),
    );
  }
}
