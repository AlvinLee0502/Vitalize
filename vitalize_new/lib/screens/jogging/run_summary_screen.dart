import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitalize/screens/community/community_screen.dart';

class RunSummaryScreen extends StatelessWidget {
  final double totalDistance;
  final Duration totalTime;
  final double totalCalories;
  final List<LatLng> path;
  final List<double> speedData;

  const RunSummaryScreen({
    super.key,
    required this.totalDistance,
    required this.totalTime,
    required this.totalCalories,
    required this.path,
    required this.speedData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Summary'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Distance: ${(totalDistance / 1000).toStringAsFixed(2)} km',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total Time: ${_formatDuration(totalTime)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Calories Burned: ${totalCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Speed vs Time',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        speedData.length,
                            (index) => FlSpot(index.toDouble(), speedData[index]),
                      ),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withAlpha(51),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _saveRunToFirestore();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CommunityScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share to Community'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRunToFirestore() async {
    final runData = {
      'distance': totalDistance,
      'time': totalTime.inSeconds,
      'calories': totalCalories,
      'path': path.map((point) => {'lat': point.latitude, 'lng': point.longitude}).toList(),
      'speedData': speedData,
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance.collection('jogging_sessions').add(runData);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
