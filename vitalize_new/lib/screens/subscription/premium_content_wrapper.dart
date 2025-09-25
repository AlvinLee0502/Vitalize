import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vitalize/screens/subscription/subscription_service.dart';

class UserSubscription {
  final String userId;
  final String professionalId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  UserSubscription({
    required this.userId,
    required this.professionalId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    return UserSubscription(
      userId: data['userId'],
      professionalId: data['professionalId'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'professionalId': professionalId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }
}

class PremiumContentWrapper extends StatelessWidget {
  final Widget child;
  final bool isPremium;
  final String professionalId;
  final String professionalName;
  final String contentType;
  final VoidCallback onSubscribePressed;
  final double blurSigma;
  final bool useOverlay;

  const PremiumContentWrapper({
    super.key,
    required this.child,
    required this.isPremium,
    required this.professionalId,
    required this.professionalName,
    required this.onSubscribePressed,
    this.contentType = 'Content',
    this.blurSigma = 10.0,
    this.useOverlay = true,
  });

  Future<bool> _checkSubscriptionStatus(String userId) async {
    try {
      // Check current subscriptions
      final subscriptionQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('professionalId', isEqualTo: professionalId)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .get();

      return subscriptionQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (!isPremium) return child;
    if (user == null) {
      return _buildLockedContent(context, 'Please log in to view premium content');
    }

    return StreamBuilder<Map<String, bool>>(
      stream: SubscriptionService.getUserSubscriptions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Show content if user is subscribed
        if (snapshot.hasData && snapshot.data?[professionalId] == true) {
          return child;
        }

        return _buildLockedContent(context);
      },
    );
  }

  Widget _buildLockedContent(BuildContext context, [String? message]) {
    return Stack(
      children: [
        if (useOverlay)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: child,
          )
        else
          child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                color: Colors.black.withAlpha(128),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock,
                      color: Colors.amber,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message ?? 'Premium $contentType by $professionalName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (message == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Subscribe to ${professionalName} to unlock',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: onSubscribePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}