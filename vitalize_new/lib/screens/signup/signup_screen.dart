import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {

  int selectedAge = 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Column(
                children: [
                  const Text(
                    'How Old Are You?',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Age in years.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              SizedBox(
                height: 200,
                child: CupertinoPicker(
                  backgroundColor: Colors.black,
                  itemExtent: 60,
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      selectedAge = index + 1;
                    });
                  },
                  scrollController: FixedExtentScrollController(initialItem: selectedAge - 1),
                  children: List<Widget>.generate(100, (int index) {
                    return Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Back and Continue Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);  // Navigate back to the first-time user screen
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      backgroundColor: Colors.grey[850],  // Darker color for back button
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
                    onPressed: () {
                      _saveAgeLocally(selectedAge);
                      Navigator.pushNamed(context, '/weight');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
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

  // Function to save user's selected age locally using SharedPreferences
  Future<void> _saveAgeLocally(int age) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('age', age);  // Save the age locally
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Age saved: $age')),
      );
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving age: $e')),
      );
    }
  }
}
