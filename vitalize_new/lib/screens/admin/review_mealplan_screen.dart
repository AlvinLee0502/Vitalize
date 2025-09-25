import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlansReviewScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MealPlansReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan Review'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meal Plans Created by Health Professionals',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildMealPlansList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlansList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('mealPlans').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final mealPlans = snapshot.data?.docs ?? [];
        if (mealPlans.isEmpty) {
          return const Center(child: Text('No meal plans found.'));
        }

        return ListView.builder(
          itemCount: mealPlans.length,
          itemBuilder: (context, index) {
            final mealPlan = mealPlans[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(mealPlan['title'] ?? 'No Title'),
                subtitle: Text('Uploaded By: ${mealPlan['uploadedBy'] ?? 'Unknown'}'),
                trailing: ElevatedButton(
                  onPressed: () => _deleteMealPlan(context, mealPlans[index].id, mealPlan['uploadedBy'] ?? 'Unknown'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteMealPlan(BuildContext context, String mealPlanId, String uploadedBy) {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Meal Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Provide a reason for deleting this meal plan:'),
              TextField(
                controller: feedbackController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Enter reason'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final feedback = feedbackController.text.trim();
                try {
                  await _firestore.collection('mealPlans').doc(mealPlanId).delete();

                  if (feedback.isNotEmpty) {
                    await _firestore.collection('feedback').add({
                      'mealPlanId': mealPlanId,
                      'uploadedBy': uploadedBy,
                      'reason': feedback,
                      'deletedBy': 'Super Admin',
                      'timestamp': Timestamp.now(),
                    });
                  }

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meal plan deleted successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting meal plan: $e')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
