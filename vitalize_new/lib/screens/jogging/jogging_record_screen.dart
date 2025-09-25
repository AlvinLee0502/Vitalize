import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vitalize/screens/jogging/session_detail_screen.dart';

class JoggingRecordScreen extends StatelessWidget {
  const JoggingRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jogging Records'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jogging_sessions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No records found.'));
          }

          final sessions = snapshot.data!.docs;
          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final data = sessions[index].data() as Map<String, dynamic>;

              final int timeInSeconds = (data['time'] ?? 0) is int
                  ? (data['time'] ?? 0) as int
                  : (data['time'] ?? 0).toInt();

              final double distance = (data['distance'] ?? 0) is int
                  ? (data['distance'] ?? 0).toDouble()
                  : (data['distance'] ?? 0) as double;

              final double calories = (data['calories'] ?? 0) is int
                  ? (data['calories'] ?? 0).toDouble()
                  : (data['calories'] ?? 0) as double;

              return ListTile(
                leading: const Icon(Icons.directions_run),
                title: Text(
                  'Session ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Calories Burnt: ${calories.toStringAsFixed(1)} kcal'),
                    Text('Distance: ${(distance / 1000).toStringAsFixed(2)} km'),
                  ],
                ),
                trailing: Text(
                  _formatDuration(Duration(seconds: timeInSeconds)),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionDetailsScreen(
                        data: sessions[index],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
}