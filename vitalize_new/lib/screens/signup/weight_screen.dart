import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  WeightScreenState createState() => WeightScreenState();
}

class WeightScreenState extends State<WeightScreen> {
  double selectedWeight = 40.0;

  Future<void> _saveUserWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weight', weight);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Weight saved: ${weight.toStringAsFixed(1)} kg')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,  // Dark theme background
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
                    'What is Your Weight?',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // Description Text
                  Text(
                    "Weight in KG. Don't worry you can always change it later.",
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
                      selectedWeight = index * 0.1;
                    });
                  },
                  scrollController: FixedExtentScrollController(
                    initialItem: (selectedWeight * 10).toInt(),  // Initialize the picker
                  ),
                  children: List<Widget>.generate(3000, (int index) {
                    return Center(
                      child: Text(
                        (index * 0.1).toStringAsFixed(1),  // Weight with 1 decimal point
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,  // Large number in white
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
                      Navigator.pop(context);  // Navigate back to the previous screen
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
                      _saveUserWeight(selectedWeight);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selected Weight: ${selectedWeight.toStringAsFixed(1)} kg'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.pushNamed(context, '/height');
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
}
