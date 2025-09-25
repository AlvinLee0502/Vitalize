import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoalProvider with ChangeNotifier {
  String _searchQuery = '';
  String _filter = 'All';
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = false;

  String get searchQuery => _searchQuery;
  String get filter => _filter;
  List<Map<String, dynamic>> get goals => _goals;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore;

  GoalProvider(this._firestore);

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _filterGoals();
  }

  void updateFilter(String selectedFilter) {
    _filter = selectedFilter;
    _filterGoals();
  }

  Future<void> fetchGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('globalGoals').get();
      _goals = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      })
          .toList();
      _filterGoals();
    } catch (e) {
      // Handle errors here
      debugPrint('Error fetching goals: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Filters and searches goals
  void _filterGoals() {
    // Perform search and filtering logic
    List<Map<String, dynamic>> filteredGoals = _goals;

    if (_filter != 'All') {
      filteredGoals = filteredGoals.where((goal) {
        if (_filter == 'Completed') {
          return goal['progress'] == 1.0; // Example for completed goals
        } else if (_filter == 'Pending') {
          return goal['progress'] < 1.0;
        }
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredGoals = filteredGoals.where((goal) {
        final title = goal['goalTitle'] ?? '';
        return title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    _goals = filteredGoals;
    notifyListeners();
  }

  /// Updates the progress of a goal
  Future<void> updateGoalProgress(String goalId, double newProgress) async {
    try {
      await _firestore.collection('globalGoals').doc(goalId).update({
        'progress': newProgress,
      });

      // Update the local goal list
      final index = _goals.indexWhere((goal) => goal['id'] == goalId);
      if (index != -1) {
        _goals[index]['progress'] = newProgress;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating goal progress: $e');
    }
  }
}
