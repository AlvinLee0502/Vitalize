import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vitalize/screens/bluetooth/scan/health_stats_cubit.dart';
import 'device_details_screen.dart';
import 'scan/fitbit_cubit.dart';
import 'scan/scan_cubit.dart';
import 'scan/shimmering_skeleton_list_tile.dart';

class HealthConnectClient {
  Future<void> initialize() async {
    try {
      debugPrint("Health Connect initialized.");
    } catch (e) {
      throw Exception("Failed to initialize Health Connect: $e");
    }
  }

  Future<bool> hasPermissions(List<String> permissions) async {
    return true;
  }

  Future<void> requestPermissions(List<String> permissions) async {
    debugPrint("Permissions requested.");
  }

  Future<List<Map<String, dynamic>>> querySteps({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return [
      {'value': 2000, 'timestamp': startTime},
      {'value': 1500, 'timestamp': endTime},
    ];
  }
}

class BleDeviceScanScreen extends StatelessWidget {
  const BleDeviceScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ScanCubit>(create: (_) => ScanCubit()),
        BlocProvider<FitbitCubit>(create: (_) => FitbitCubit()),
        BlocProvider<HealthStatsCubit>(create: (_) => HealthStatsCubit()),
      ],
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildSyncButtons(context),
              _buildFitbitStats(context), // New method for Fitbit stats
              _buildDevicesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFitbitStats(BuildContext context) {
    return BlocConsumer<HealthStatsCubit, HealthStatsState>(
      listener: (context, state) {
        if (state is HealthStatsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is HealthStatsLoaded && state.source == 'fitbit') {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fitbit Stats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 26),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.watch, size: 16, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text(
                            'Fitbit',
                            style: TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.favorite,
                      value: state.formattedHeartRate,
                      label: 'Heart Rate',
                      unit: 'BPM',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.directions_walk,
                      value: state.formattedSteps,
                      label: 'Steps',
                      unit: 'today',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else if (state is HealthStatsLoading) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.watch_outlined,
                    size: 32,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Fitbit data available\nTap the Fitbit button to sync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSyncButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildSyncButton(
              onTap: () async {
                final currentContext = context;
                final fitbitCubit = currentContext.read<FitbitCubit>();

                try {
                  // Show a loading indicator
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(content: Text("Connecting to Fitbit...")),
                  );

                  await fitbitCubit.authenticateFitbit(currentContext);

                  if (!currentContext.mounted) return;

                  // Check the state after authentication
                  final state = fitbitCubit.state;
                  if (state is FitbitAuthenticated) {
                    final fitbitData = await fitbitCubit.fetchFitbitData();

                    if (!currentContext.mounted) return;

                    currentContext.read<HealthStatsCubit>().updateFromFitbit(fitbitData);
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(
                        content: Text("Successfully synced with Fitbit!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else if (state is FitbitError) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${state.message}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (!currentContext.mounted) return;
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(
                      content: Text("Failed to sync: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: Icons.watch,
              label: 'Fitbit',
              color: Colors.purple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSyncButton(
              onTap: () => _syncHealthConnect(context),
              icon: Icons.health_and_safety,
              label: 'Health',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return BlocBuilder<FitbitCubit, FitbitState>(
      builder: (context, state) {
        bool isLoading = state is FitbitAuthenticating;

        return Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withAlpha(26),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isLoading ? null : onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(icon, color: color, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    isLoading ? 'Syncing...' : label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncHealthConnect(BuildContext context) async {
    final healthStatsCubit = context.read<HealthStatsCubit>();

    try {
      final healthConnectClient = HealthConnectClient();
      await healthConnectClient.initialize();

      final granted = await healthConnectClient.hasPermissions(['steps']);
      if (!granted) {
        await healthConnectClient.requestPermissions(['steps']);
      }

      final stepData = await healthConnectClient.querySteps(
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now(),
      );

      if (stepData.isNotEmpty) {
        healthStatsCubit.updateFromHealthConnect(stepData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Health data synced successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No new data found.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Health Connect Sync Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Device Scanner',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          BlocBuilder<ScanCubit, ScanStates>(
            builder: (context, state) {
              return GestureDetector(
                onTap: () async {
                  if (state is! ScanDevicesLoadingState) {
                    final scanCubit = context.read<ScanCubit>();
                    await scanCubit.startScanning(context);
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state is ScanDevicesLoadingState
                        ? Colors.grey[300]
                        : Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: state is ScanDevicesLoadingState
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  )
                      : const Icon(
                    Icons.bluetooth_searching,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStats(BuildContext context) {
    return BlocConsumer<HealthStatsCubit, HealthStatsState>(
      listener: (context, state) {
        if (state is HealthStatsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is HealthStatsLoaded) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Health Metrics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.favorite,
                      value: state.formattedHeartRate,
                      label: 'BPM',
                      unit: 'BPM',
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.directions_walk,
                      value: state.formattedSteps,
                      label: 'Steps',
                      unit: 'steps',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else if (state is HealthStatsLoading) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                _buildLoadingStatCard(color: Colors.red),
                const SizedBox(width: 12),
                _buildLoadingStatCard(color: Colors.blue),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No Fitbit data available. Sync to get updates.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }
      },
    );
  }

  Widget _buildLoadingStatCard({required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required String unit,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDevicesList() {
    return Expanded(
      child: BlocConsumer<ScanCubit, ScanStates>(
        listener: (context, state) {
          if (state is ScanDevicesErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final scanCubit = context.read<ScanCubit>();

          if (state is ScanDevicesLoadingState) {
            return ListView.builder(
              itemCount: 5,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemBuilder: (context,
                  index) => const ShimmeringSkeletonListTile(),
            );
          }

          if (scanCubit.devicesList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_disabled, size: 48,
                      color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No devices found\nTap the bluetooth button to start scanning',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: scanCubit.devicesList.length,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemBuilder: (context, index) {
              final device = scanCubit.devicesList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(26),
                    child: Icon(
                      (device['name'] as String?)?.toLowerCase().contains(
                          'fitbit') == true
                          ? Icons.watch
                          : Icons.bluetooth,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    device['name'] ?? 'Unknown Device',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(device['mac'] ?? 'No MAC Address'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeviceDetailsScreen(
                              device: device['device'],
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
