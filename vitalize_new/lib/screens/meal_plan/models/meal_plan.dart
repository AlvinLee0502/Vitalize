import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MealPlan {
  final String id;
  final String name;
  final String description;
  final String authorId;
  final String authorName;
  final bool isPremium;
  final String? imageUrl;
  final int date;
  final double averageCalories;
  final String status;

  MealPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.isPremium,
    this.imageUrl,
    required this.date,
    required this.averageCalories,
    required this.status,
  });

  factory MealPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlan(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      authorId: data['healthProfessionalID'] ?? '',
      authorName: data['authorName'] ?? '',
      isPremium: data['isPremium'] ?? false,
      imageUrl: data['media_items'],
      date: (data['createdAt'] as Timestamp?)?.toDate().millisecondsSinceEpoch ?? 0,
      averageCalories: (data['averageCalories'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'inactive',
    );
  }
}

class MealPlanRepository {
  static Stream<List<MealPlan>> getActiveMealPlans() {
    return FirebaseFirestore.instance
        .collection('plans')
        .where('type', isEqualTo: 'meal')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MealPlan.fromFirestore(doc))
          .toList();
    });
  }

  static Future<void> addUserMealPlan(String userId, String planId) async {
    final userMealPlanRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('meal_plan')
        .doc(planId);

    await userMealPlanRef.set({
      'userId': userId,
      'planId': planId,
    });
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .update({
      'engagementCount': FieldValue.increment(1)
    });
  }
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Theme.of(context).primaryColor,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
