import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore;
  final String userId;

  NotificationService({required this.userId})
      : _firestore = FirebaseFirestore.instance;

  // Create a notification
  Future<void> createNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    String? relatedDocId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _firestore.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'message': message,
      'type': type,
      'relatedDocId': relatedDocId,
      'additionalData': additionalData,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Get notifications stream for current user
  Stream<QuerySnapshot> getNotificationsStream() {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Get unread count stream
  Stream<QuerySnapshot> getUnreadCountStream() {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final batch = _firestore.batch();
    final unreadNotifications = await _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}