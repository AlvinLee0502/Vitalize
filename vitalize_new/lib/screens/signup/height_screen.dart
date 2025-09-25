import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HeightScreen extends StatefulWidget {
  const HeightScreen({super.key});

  @override
  HeightScreenState createState() => HeightScreenState();
}

class HeightScreenState extends State<HeightScreen> {
  double selectedHeight = 170.0;

  Future<void> _saveUserHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('height', height);  // Save the height locally
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Height saved: ${height.toStringAsFixed(1)} cm')),
    );
  }

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
                    'What is Your Height?',
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
                    "Height in CM. Don't worry you can always change it later.",
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
                      selectedHeight = 100.0 + index * 0.1;
                    });
                  },
                  scrollController: FixedExtentScrollController(
                    initialItem: ((selectedHeight - 100.0) * 10).toInt(),
                  ),
                  children: List<Widget>.generate(1501, (int index) {
                    return Center(
                      child: Text(
                        (100.0 + index * 0.1).toStringAsFixed(1),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                    onPressed: () {
                      _saveUserHeight(selectedHeight);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selected Height: ${selectedHeight.toStringAsFixed(1)} cm'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      Navigator.pushNamed(context, '/goal');
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
