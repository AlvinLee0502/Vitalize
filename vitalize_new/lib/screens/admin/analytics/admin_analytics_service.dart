import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAnalyticsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AdminAnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> trackActivity(String activityType, Map<String, dynamic> details) async {
    try {
      // Log the activity
      await _firestore.collection('adminActivities').add({
        'activityType': activityType,
        'details': details,
        'adminId': _auth.currentUser?.uid,
        'adminEmail': _auth.currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update analytics counters
      final analyticsRef = _firestore.collection('adminAnalytics').doc('statistics');

      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(analyticsRef);

        if (!docSnapshot.exists) {
          transaction.set(analyticsRef, {
            'totalActivities': 1,
            'activityCounts': {activityType: 1},
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          final data = docSnapshot.data() as Map<String, dynamic>;
          final activityCounts = Map<String, dynamic>.from(data['activityCounts'] ?? {});

          activityCounts[activityType] = (activityCounts[activityType] ?? 0) + 1;

          transaction.update(analyticsRef, {
            'totalActivities': FieldValue.increment(1),
            'activityCounts': activityCounts,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error tracking activity: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getRecentActivities() {
    return _firestore
        .collection('adminActivities')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    try {
      final QuerySnapshot activities = await _firestore
          .collection('adminActivities')
          .orderBy('timestamp', descending: true)
          .get();

      // Get current date for calculations
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisWeek = today.subtract(Duration(days: today.weekday - 1));
      final thisMonth = DateTime(now.year, now.month, 1);

      int todayCount = 0;
      int weekCount = 0;
      int monthCount = 0;
      Map<String, int> activityTypeCount = {};
      Map<String, int> adminActivityCount = {};

      for (var doc in activities.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final activityType = data['activityType'] as String;
        final adminEmail = data['adminEmail'] as String?;

        // Count by time period
        if (timestamp.isAfter(today)) todayCount++;
        if (timestamp.isAfter(thisWeek)) weekCount++;
        if (timestamp.isAfter(thisMonth)) monthCount++;

        // Count by activity type
        activityTypeCount[activityType] = (activityTypeCount[activityType] ?? 0) + 1;

        // Count by admin
        if (adminEmail != null) {
          adminActivityCount[adminEmail] = (adminActivityCount[adminEmail] ?? 0) + 1;
        }
      }

      return {
        'totalActivities': activities.size,
        'todayCount': todayCount,
        'weekCount': weekCount,
        'monthCount': monthCount,
        'activityTypeCount': activityTypeCount,
        'adminActivityCount': adminActivityCount,
      };
    } catch (e) {
      print('Error getting analytics summary: $e');
      rethrow;
    }
  }

  Future<void> createAuditLog(String action, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('auditLogs').add({
        'action': action,
        'details': details,
        'performedBy': _auth.currentUser?.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating audit log: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getAuditLogs({
    String? action,
    String? performedBy,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query query = _firestore.collection('auditLogs')
        .orderBy('timestamp', descending: true);

    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }

    if (performedBy != null) {
      query = query.where('performedBy', isEqualTo: performedBy);
    }

    if (startDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.limit(limit).snapshots();
  }

  Future<Map<String, dynamic>> getAuditLogStats() async {
    try {
      final QuerySnapshot logs = await _firestore
          .collection('auditLogs')
          .orderBy('timestamp', descending: true)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisWeek = today.subtract(Duration(days: today.weekday - 1));
      final thisMonth = DateTime(now.year, now.month, 1);

      int todayCount = 0;
      int weekCount = 0;
      int monthCount = 0;
      Map<String, int> actionTypes = {};
      Map<String, int> userActivity = {};

      for (var doc in logs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final action = data['action'] as String;
        final user = data['performedBy'] as String?;

        if (timestamp.isAfter(today)) todayCount++;
        if (timestamp.isAfter(thisWeek)) weekCount++;
        if (timestamp.isAfter(thisMonth)) monthCount++;

        actionTypes[action] = (actionTypes[action] ?? 0) + 1;
        if (user != null) {
          userActivity[user] = (userActivity[user] ?? 0) + 1;
        }
      }

      return {
        'totalLogs': logs.size,
        'todayCount': todayCount,
        'weekCount': weekCount,
        'monthCount': monthCount,
        'actionTypes': actionTypes,
        'userActivity': userActivity,
      };
    } catch (e) {
      print('Error getting audit log stats: $e');
      rethrow;
    }
  }

  Future<void> deleteOldAuditLogs(int daysToKeep) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final QuerySnapshot oldLogs = await _firestore
          .collection('auditLogs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting old audit logs: $e');
      rethrow;
    }
  }
}