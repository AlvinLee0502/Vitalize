import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutPlan {
  final String id;
  final String name;
  final String authorName;
  final String description;
  final String difficulty;
  final bool isPremium;
  final String coverImage;
  final List<Map<String, dynamic>> mediaItems;
  final double averageRating;
  final String authorId;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.authorName,
    required this.description,
    required this.difficulty,
    required this.isPremium,
    required this.coverImage,
    required this.mediaItems,
    required this.averageRating,
    required this.authorId,
  });

  factory WorkoutPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<Map<String, dynamic>> formattedMediaItems = [];
    if (data['media_items'] != null) {
      formattedMediaItems = (data['media_items'] as List<dynamic>).map((item) {
        if (item is String) {
          return {
            'type': item.toLowerCase().endsWith('.mp4') ? 'video' : 'image',
            'url': item
          };
        } else if (item is Map<String, dynamic>) {
          return item;
        }
        return <String, dynamic>{
          'type': 'image',
          'url': ''
        };
      }).toList();
    }

    return WorkoutPlan(
      id: doc.id,
      name: data['name'] as String? ?? '',
      authorName: data['author_name'] as String? ?? '',  // Changed from authorName to author_name
      description: data['description'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? '',
      isPremium: data['is_premium'] as bool? ?? false,  // Changed from isPremium to is_premium
      coverImage: data['cover_image'] as String? ?? '',
      mediaItems: formattedMediaItems,
      averageRating: (data['average_rating'] as num?)?.toDouble() ?? 0.0,  // Changed from rating to average_rating
      authorId: data['author_id'] as String? ?? '',  // Changed from healthProfessionalID to author_id
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'author_name': authorName,
      'description': description,
      'difficulty': difficulty,
      'is_premium': isPremium,
      'cover_image': coverImage,
      'media_items': mediaItems.map((item) => {
        'type': item['type'],
        'url': item['url'],
      }).toList(),
      'average_rating': averageRating,
      'author_id': authorId,
      'type': 'workout',
      'status': 'active',
    };
  }
}

class WorkoutRepository {
  static Future<void> addUserWorkoutPlan(String userId, WorkoutPlan workoutPlan) async {
    if (userId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'User ID cannot be empty',
      );
    }

    if (workoutPlan.id.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Workout plan ID cannot be empty',
      );
    }

    final db = FirebaseFirestore.instance;

    // Use a transaction to ensure data consistency
    return db.runTransaction((transaction) async {
      // Create document references with validated paths
      final planRef = db.collection('plans').doc(workoutPlan.id);
      final userWorkoutPlanRef = db
          .collection('users')
          .doc(userId)
          .collection('workout_plan')
          .doc(workoutPlan.id);

      // Check if plan exists and is active
      final planDoc = await transaction.get(planRef);
      if (!planDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Workout plan does not exist',
        );
      }

      final planData = planDoc.data() as Map<String, dynamic>;
      if (planData['status'] != 'active') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Workout plan is not active',
        );
      }

      // Check if user already has this plan
      final existingPlan = await transaction.get(userWorkoutPlanRef);
      if (existingPlan.exists) {
        return; // Plan already added, no need to proceed
      }

      // Add complete plan to user's collection
      transaction.set(userWorkoutPlanRef, {
        'user_id': userId,
        'plan_id': workoutPlan.id,
        'added_at': FieldValue.serverTimestamp(),
        'plan_data': {
          // Basic info
          'name': workoutPlan.name,
          'author_name': workoutPlan.authorName,
          'author_id': workoutPlan.authorId,
          'difficulty': workoutPlan.difficulty,
          'is_premium': workoutPlan.isPremium,

          // Full content
          'description': workoutPlan.description,
          'cover_image': workoutPlan.coverImage,
          'media_items': workoutPlan.mediaItems,
          'average_rating': workoutPlan.averageRating,

          // Metadata
          'version': planData['version'] ?? 1,
          'last_synced': FieldValue.serverTimestamp(),
        },
        'progress': {
          'started': false,
          'completed': false,
          'last_activity': null,
        }
      });

      // Update engagement count on original plan
      transaction.update(planRef, {
        'engagement_count': FieldValue.increment(1),
        'last_accessed': FieldValue.serverTimestamp(),
      });
    });
  }
}