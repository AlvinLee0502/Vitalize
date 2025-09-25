import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutsReviewScreen extends StatefulWidget {
  const WorkoutsReviewScreen({super.key});

  @override
  WorkoutsReviewScreenState createState() => WorkoutsReviewScreenState();
}

class WorkoutsReviewScreenState extends State<WorkoutsReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _feedbackController = TextEditingController();
  List<DocumentSnapshot> _workoutDocuments = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchInitialWorkouts();
  }

  Future<void> _fetchInitialWorkouts() async {
    try {
      Query query = _firestore
          .collection('workout_plans')
          .where('status', isEqualTo: 'pending')
          .orderBy('title')
          .limit(_limit);

      final snapshot = await query.get();
      setState(() {
        _workoutDocuments = snapshot.docs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _limit;
      });
    } catch (e) {
      _showSnackBar('Error fetching workouts: $e');
    }
  }

  Future<void> _loadMoreWorkouts() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      Query query = _firestore
          .collection('workout_plans')
          .where('status', isEqualTo: 'pending')
          .orderBy('title')
          .limit(_limit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      setState(() {
        _workoutDocuments.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _limit;
      });
    } catch (e) {
      _showSnackBar('Error loading more workouts: $e');
    }

    setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout Reviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: _workoutDocuments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _workoutDocuments.length + 1,
        itemBuilder: (context, index) {
          if (index < _workoutDocuments.length) {
            final workout = _workoutDocuments[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                title: Text(
                  workout['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text('Created By: ${workout['createdBy'] ?? 'Unknown'}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _approveWorkout(_workoutDocuments[index].id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Approve'),
                    ),
                    ElevatedButton(
                      onPressed: () => _editWorkoutDialog(
                          _workoutDocuments[index].id, workout['title'] ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Edit'),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteWorkout(
                          _workoutDocuments[index].id, workout['createdBy'] ?? 'Unknown'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return _hasMore
                ? Center(
              child: ElevatedButton(
                onPressed: _loadMoreWorkouts,
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : const Text('Load More'),
              ),
            )
                : const Center(child: Text('No more workouts to load.'));
          }
        },
      ),
    );
  }

  Future<void> _editWorkoutDialog(String workoutId, String currentTitle) async {
    final TextEditingController titleController =
    TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Workout'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Workout Title'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firestore
                      .collection('workout_plans')
                      .doc(workoutId)
                      .update({
                    'title': titleController.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showSnackBar('Workout updated successfully.');
                } catch (e) {
                  _showSnackBar('Error updating workout: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveWorkout(String workoutId) async {
    try {
      await _firestore.collection('workout_plans').doc(workoutId).update({
        'status': 'approved',
      });
      _showSnackBar('Workout approved successfully.');
      setState(() => _workoutDocuments.removeWhere((doc) => doc.id == workoutId));
    } catch (e) {
      _showSnackBar('Error approving workout: $e');
    }
  }

  Future<void> _deleteWorkout(String workoutId, String uploadedBy) async {
    _feedbackController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Workout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Provide a reason for deleting this workout:'),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Enter reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final feedback = _feedbackController.text.trim();
                try {
                  await _firestore.collection('workout_plans').doc(workoutId).delete();
                  if (feedback.isNotEmpty) {
                    await _firestore.collection('feedback').add({
                      'workoutId': workoutId,
                      'uploadedBy': uploadedBy,
                      'reason': feedback,
                      'deletedBy': 'Admin',
                      'timestamp': Timestamp.now(),
                    });
                  }
                  Navigator.pop(context);
                  setState(() => _workoutDocuments.removeWhere((doc) => doc.id == workoutId));
                  _showSnackBar('Workout deleted successfully.');
                } catch (e) {
                  _showSnackBar('Error deleting workout: $e');
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
