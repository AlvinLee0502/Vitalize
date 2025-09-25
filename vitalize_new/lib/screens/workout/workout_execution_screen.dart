/*import 'package:flutter/material.dart';

import 'models/workout_plans.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutPlan workoutPlan;

  const WorkoutExecutionScreen({
    super.key,
    required this.workoutPlan,
  });

  @override
  WorkoutExecutionScreenState createState() => WorkoutExecutionScreenState();
}

class WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  int currentExerciseIndex = 0;
  bool isResting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutPlan.name),
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (currentExerciseIndex + 1) / widget.workoutPlan.exercises.length,
          ),

          // Current exercise display
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Exercise ${currentExerciseIndex + 1}/${widget.workoutPlan.exercises.length}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Exercise media (video/image)
                  // Exercise instructions
                  // Timer/counter if applicable
                ],
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: currentExerciseIndex > 0
                      ? () => setState(() => currentExerciseIndex--)
                      : null,
                ),
                IconButton(
                  icon: Icon(isResting ? Icons.play_arrow : Icons.pause),
                  onPressed: () => setState(() => isResting = !isResting),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: currentExerciseIndex < widget.workoutPlan.exercises.length - 1
                      ? () => setState(() => currentExerciseIndex++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}*/