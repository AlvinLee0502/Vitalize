import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<Map<String, bool>> getUserSubscriptions() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({});
    }

    return _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      final Map<String, bool> subscriptions = {};
      for (var doc in snapshot.docs) {
        final profId = doc.data()['healthProfessionalId'] ?? doc.data()['professionalId'];
        if (profId != null) {
          subscriptions[profId as String] = true;
        }
      }
      return subscriptions;
    });
  }

  static Future<bool> isSubscribedToHealthProfessional(String healthProfessionalId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    final snapshot = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .where('endDate', isGreaterThan: Timestamp.now())
        .where('professionalId', isEqualTo: healthProfessionalId)
        .get();

    if (snapshot.docs.isEmpty) {
      final altSnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .where('healthProfessionalId', isEqualTo: healthProfessionalId)
          .get();

      return altSnapshot.docs.isNotEmpty;
    }

    return true;
  }
}