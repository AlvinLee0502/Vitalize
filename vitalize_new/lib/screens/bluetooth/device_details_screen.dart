import 'package:flutter/material.dart';

class DeviceDetailsScreen extends StatelessWidget {
  final dynamic device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final String deviceName = device.name.isNotEmpty ? device.name : 'Unknown Device';
    final String deviceMac = device.id.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Information
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Device Name', deviceName),
                    const SizedBox(height: 8),
                    _buildInfoRow('MAC Address', deviceMac),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Text(
              'Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _connectToDevice(context),
              icon: const Icon(Icons.bluetooth),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _disconnectDevice(context),
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
              ),
            ),
            const Spacer(),

            // Debug/Info Section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Info',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('RSSI: ${device.rssi ?? 'Unknown'}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _connectToDevice(BuildContext context) async {
    try {
      await device.connect();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device connected successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  void _disconnectDevice(BuildContext context) async {
    try {
      await device.disconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device disconnected successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to disconnect: $e')),
      );
    }
  }
}
