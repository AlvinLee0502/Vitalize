import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlanService {
  static Future<Map<String, dynamic>?> fetchPlanDetails(String planId) async {
    try {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();

      return planDoc.exists ? planDoc.data() : null;
    } catch (e) {
      debugPrint("Error fetching plan details: $e");
      return null;
    }
  }
}
