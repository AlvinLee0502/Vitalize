import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  GoalScreenState createState() => GoalScreenState();
}

class GoalScreenState extends State<GoalScreen> {
  // Variables to store the selected goals
  Map<String, bool> goals = {
    'Get Fitter': false,
    'Gain Weight': false,
    'Lose Weight': false,
    'Building Muscles': false,
    'Improving Endurance': false,
    'Others': false,
  };

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in goals.keys) {
      goals[key] = prefs.getBool(key) ?? false;
    }
    setState(() {});
  }

  Future<void> _saveSelectedGoals() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> selectedGoals = goals.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    await prefs.setStringList('selectedGoals', selectedGoals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What is Your Goal?',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You can choose more than one. Don't worry, you can always change it later.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: goals.keys.map((String key) {
                    return CheckboxListTile(
                      title: Text(
                        key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      value: goals[key],
                      activeColor: Colors.purple,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setState(() {
                          goals[key] = value!;
                        });
                      },
                    );
                  }).toList(),
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
                    onPressed: () async {
                      // Save the selected goals and navigate
                      await _saveSelectedGoals();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Goals saved successfully!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pushNamed(context, '/activityLevel');
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
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
