import 'dart:math'; // Import math for trigonometric functions
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SessionDetailsScreen extends StatelessWidget {
  final QueryDocumentSnapshot data;

  const SessionDetailsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: data['duration'] ?? 0);
    final path = (data['path'] ?? []) as List<dynamic>;
    final speeds = _calculateSpeeds(path);
    if (speeds.isEmpty) {
      return const Center(child: Text('No speed data available'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Session Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('Date and Time: ${data['timestamp'].toDate()}'),
            Text('Calories Burnt: ${data['calories'] ?? 0} kcal'),
            Text(
                'Distance Ran: ${(data['distance'] ?? 0 / 1000).toStringAsFixed(2)} km'),
            Text('Duration: ${_formatDuration(duration)}'),
            const SizedBox(height: 16),
            const Text(
              'Speed Over Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: speeds.isEmpty ? 10 : speeds.reduce(max) * 1.2,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        speeds.length,
                            (index) => FlSpot(index.toDouble(), speeds[index]),
                      ),
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withAlpha(50),
                            Colors.blueAccent.withAlpha(30),
                          ],
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()} min');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toStringAsFixed(1)} km/h');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              )
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  List<double> _calculateSpeeds(List<dynamic> path) {
    if (path.isEmpty || path.length < 2) return [0.0];
    List<double> speeds = [];

    for (int i = 1; i < path.length; i++) {
      final prevTimestamp = path[i - 1]['timestamp'];
      final currTimestamp = path[i]['timestamp'];
      if (prevTimestamp == null || currTimestamp == null) continue;
      final int prevTimeMs = prevTimestamp is Timestamp
          ? prevTimestamp.toDate().millisecondsSinceEpoch
          : prevTimestamp;
      final int currTimeMs = currTimestamp is Timestamp
          ? currTimestamp.toDate().millisecondsSinceEpoch
          : currTimestamp;

      final LatLng prevPoint = LatLng(
          (path[i - 1]['lat'] ?? 0.0).toDouble(),
          (path[i - 1]['lng'] ?? 0.0).toDouble()
      );
      final LatLng currPoint = LatLng(
          (path[i]['lat'] ?? 0.0).toDouble(),
          (path[i]['lng'] ?? 0.0).toDouble()
      );
      final distance = _calculateDistance(prevPoint, currPoint) / 1000;
      final timeDiff = (currTimeMs - prevTimeMs) / (1000 * 3600);
      final speed = timeDiff > 0 ? distance / timeDiff : 0.0;
      speeds.add(speed);
    }
    return speeds.isEmpty ? [0.0] : speeds;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double radiusOfEarthKm = 6371;
    final double latDiff = (point2.latitude - point1.latitude) * (pi / 180);
    final double lngDiff = (point2.longitude - point1.longitude) * (pi / 180);
    final double a = (sin(latDiff / 2) * sin(latDiff / 2)) +
        cos(point1.latitude * (pi / 180)) *
            cos(point2.latitude * (pi / 180)) *
            sin(lngDiff / 2) *
            sin(lngDiff / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radiusOfEarthKm * c * 1000;
  }
}
