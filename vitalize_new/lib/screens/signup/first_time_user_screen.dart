import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FirstTimeUserScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const FirstTimeUserScreen({super.key, required this.onComplete});

  Future<void> _trackGetStarted(FirebaseAnalytics analytics) async {
    await analytics.logEvent(
      name: 'get_started_clicked',
      parameters: <String, Object>{
        'screen': 'FirstTimeUserScreen',
      },
    );
  }

  Future<void> _trackSignInClicked(FirebaseAnalytics analytics) async {
    await analytics.logEvent(
      name: 'sign_in_clicked',
      parameters: <String, Object>{
        'screen': 'FirstTimeUserScreen',
      },
    );
  }

  void _navigateToSignUp(BuildContext context) {
    onComplete();
    Navigator.pushNamed(context, '/signup');
  }

  void _navigateToSignIn(BuildContext context) {
    onComplete();
    Navigator.pushNamed(context, '/signIn');
  }

  @override
  Widget build(BuildContext context) {
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A148C),
              Color(0xFF880E4F),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const Icon(
                  Icons.apartment,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Vitalize!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Your journey to a healthier lifestyle starts here. Track your workouts, monitor progress, and stay fit with ease!',
                  style: TextStyle(fontSize: 16, color: Colors.grey[300]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _trackGetStarted(analytics);
                      _navigateToSignUp(context);
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _trackSignInClicked(analytics);
                        _navigateToSignIn(context);
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
