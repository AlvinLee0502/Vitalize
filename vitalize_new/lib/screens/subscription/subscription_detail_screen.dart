import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionDetailsScreen extends StatelessWidget {
  final String professionalId;
  final String professionalName;

  const SubscriptionDetailsScreen({
    super.key,
    required this.professionalId,
    required this.professionalName,
  });

  Future<void> _handleSubscription(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to subscribe.')),
      );
      return;
    }

    try {
      // Check if user is already subscribed
      final existingSubscription = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: user.uid)
          .where('professionalId', isEqualTo: professionalId)
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .get();

      if (existingSubscription.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already subscribed to this professional.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      bool paymentSuccess = await _processPayment();

      if (paymentSuccess) {
        // Create subscription document with proper error handling
        try {
          await FirebaseFirestore.instance.collection('subscriptions').add({
            'userId': user.uid,
            'professionalId': professionalId,
            'startDate': Timestamp.now(),
            'endDate': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 30)),
            ),
            'isActive': true,
            'status': 'active', // Added to match SubscriptionService query
            'healthProfessionalId': professionalId, // Added to match SubscriptionService query
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully subscribed to ${professionalName}\'s content!'),
              ),
            );
            Navigator.pop(context);
          }
        } catch (firestoreError) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving subscription: $firestoreError')),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment failed. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<bool> _processPayment() async {
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 48,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Main content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Professional's profile section
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(professionalId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final profilePic = userData?['profile_picture'] as String?;

                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: profilePic != null
                                ? NetworkImage(profilePic)
                                : null,
                            child: profilePic == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            professionalName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userData?['specialization'] ?? 'Health Professional',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Subscribe to Access Premium Content',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Get exclusive access to premium content, personalized advice, and more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Features section
                  _buildFeatureCard(
                    Icons.lock_open,
                    'Exclusive Content',
                    'Access all premium posts and content',
                  ),
                  _buildFeatureCard(
                    Icons.chat,
                    'Direct Communication',
                    'Priority messaging with $professionalName',
                  ),
                  _buildFeatureCard(
                    Icons.star,
                    'Early Access',
                    'Be the first to see new content and updates',
                  ),
                  _buildFeatureCard(
                    Icons.workspace_premium,
                    'Premium Resources',
                    'Access specialized guides and resources',
                  ),
                  const SizedBox(height: 32),

                  // Subscribe button
                  ElevatedButton(
                    onPressed: () => _handleSubscription(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Subscribe Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price info
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        const TextSpan(text: 'Subscribe for '),
                        TextSpan(
                          text: '\$4.99/month',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}