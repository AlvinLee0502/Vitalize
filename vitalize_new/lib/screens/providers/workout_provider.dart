import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../workout/models/workout_plans.dart';

class WorkoutProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<WorkoutPlan> _workoutPlans = [];
  bool _isLoading = false;
  WorkoutPlan? _selectedWorkoutPlan;

  List<WorkoutPlan> get workoutPlans => _workoutPlans;
  bool get isLoading => _isLoading;
  WorkoutPlan? get selectedWorkoutPlan => _selectedWorkoutPlan;

  Future<void> initialize(String initialDifficulty) async {
    await fetchWorkoutPlans(initialDifficulty);
  }

  Future<void> fetchWorkoutPlans(String difficulty) async {
    _isLoading = true;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('plans')
          .where('type', isEqualTo: 'workout')
          .where('difficulty', isEqualTo: difficulty)
          .where('isApproved', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      _workoutPlans = querySnapshot.docs
          .map((doc) => WorkoutPlan.fromFirestore(doc))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void handleWorkoutSelection(WorkoutPlan? plan) {
    _selectedWorkoutPlan = plan;
    notifyListeners();
  }
}