import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vitalize/screens/bluetooth/scan/health_stats_cubit.dart';

class HealthStatsScreen extends StatelessWidget {
  const HealthStatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Stats'),
        centerTitle: true,
      ),
      body: BlocConsumer<HealthStatsCubit, HealthStatsState>(
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
          if (state is HealthStatsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is HealthStatsLoaded) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Source: ${state.source == 'fitbit' ? 'Fitbit' : 'Health Connect'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: state.formattedSteps,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    icon: Icons.local_fire_department,
                    label: 'Calories Burned',
                    value: state.formattedCalories,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    icon: Icons.favorite,
                    label: 'Heart Rate (BPM)',
                    value: state.formattedHeartRate,
                    color: Colors.red,
                  ),
                ],
              ),
            );
          } else {
            return const Center(
              child: Text('No health data available.'),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
