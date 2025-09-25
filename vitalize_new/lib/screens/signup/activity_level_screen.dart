import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  ActivityLevelScreenState createState() => ActivityLevelScreenState();
}

class ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String _selectedActivityLevel = "Beginner";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActivityLevel(); // Load saved activity level preference
  }

  Future<void> _loadActivityLevel() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedActivityLevel = prefs.getString('activityLevel');
    if (savedActivityLevel != null) {
      setState(() {
        _selectedActivityLevel = savedActivityLevel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title "Physical Activity Level?"
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Physical Activity Level?',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Description
                  Text(
                    "Choose your regular activity level.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),

              Expanded(
                child: ListView(
                  children: <Widget>[
                    RadioListTile<String>(
                      title: const Text(
                        'Beginner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      value: 'Beginner',
                      groupValue: _selectedActivityLevel,
                      activeColor: Colors.purple,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedActivityLevel = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Intermediate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      value: 'Intermediate',
                      groupValue: _selectedActivityLevel,
                      activeColor: Colors.purple,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedActivityLevel = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Advanced',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      value: 'Advanced',
                      groupValue: _selectedActivityLevel,
                      activeColor: Colors.purple,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedActivityLevel = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      backgroundColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                      setState(() {
                        _isLoading = true;
                      });

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('activityLevel', _selectedActivityLevel);

                      // Navigate to the complete profile screen
                      if (mounted) {
                        setState(() {
                          _isLoading = false; // Stop loading
                        });
                        Navigator.pushNamed(context, '/completeProfile'); // Navigate only if mounted
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                        : const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
