import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/meal_data.dart';


class FoodScreen extends StatefulWidget {
  final String mealType;
  final String selectedDate;

  const FoodScreen({
    super.key,
    required this.mealType,
    required this.selectedDate,
  });

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _foods = [];
  bool _isLoading = false;
  bool _isLocalSearch = true;
  String? _error;

  final String apiKey = 'm0Kvzx2NymXc3dBIfqZYyAFqalWqbKbbSzzCovPV';

  @override
  void initState() {
    super.initState();
    _searchLocalFood('');
  }

  Future<void> _searchLocalFood(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      QuerySnapshot snapshot;
      if (query.isEmpty) {
        snapshot = await _firestore.collection('food_items').limit(20).get();
      } else {
        snapshot = await _firestore
            .collection('food_items')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
      }

      setState(() {
        _foods = snapshot.docs.map((doc) {
          final mealData = MealData.fromJson(doc.data() as Map<String, dynamic>);
          return mealData.toJson();
        }).toList();
      });
    } catch (e) {
      setState(() {
        _error = 'Error searching local database: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUSDAFood(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$apiKey&query=$query&pageSize=20'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> foods = (data['foods'] as List).map((food) {
          return {
            'name': food['description'],
            'calories': _getNutrientValue(food['foodNutrients'], 'Energy'),
            'protein': _getNutrientValue(food['foodNutrients'], 'Protein'),
            'carbs': _getNutrientValue(
                food['foodNutrients'], 'Carbohydrate, by difference'),
            'fats': _getNutrientValue(
                food['foodNutrients'], 'Total lipid (fat)'),
          };
        }).toList();

        setState(() {
          _foods = foods;
        });
      } else {
        setState(() {
          _error = 'Error fetching from USDA: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching USDA database: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _getNutrientValue(List nutrients, String nutrientName) {
    final nutrient = nutrients.firstWhere(
          (n) => n['nutrientName'] == nutrientName,
      orElse: () => {'value': 0},
    );
    return (nutrient['value'] ?? 0).toDouble();
  }

  Future<void> _saveSelectedFood(Map<String, dynamic> food) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final mealData = MealData.fromJson(food);
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('meal_logs')
            .add({
          'mealType': widget.mealType,
          'date': widget.selectedDate,
          ...mealData.toJson(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Food added to ${widget.mealType}!')),
        );
      } else {
        throw Exception('User not logged in');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add food: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Food to ${widget.mealType}'),
        actions: [
          TextButton.icon(
            icon: Icon(
              _isLocalSearch ? Icons.cloud : Icons.storage,
              color: Colors.white,
            ),
            label: Text(
              _isLocalSearch ? 'USDA' : 'Local',
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () {
              setState(() {
                _isLocalSearch = !_isLocalSearch;
              });
              _searchLocalFood('');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _isLocalSearch
                    ? 'Search local database...'
                    : 'Search USDA database...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _foods.clear();
                    if (_isLocalSearch) {
                      _searchLocalFood('');
                    }
                  },
                )
                    : null,
              ),
              onChanged: (value) {
                if (_isLocalSearch) {
                  _searchLocalFood(value);
                } else if (value.length >= 3) {
                  _searchUSDAFood(value);
                }
              },
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _foods.length,
                itemBuilder: (context, index) {
                  final food = _foods[index];
                  return ListTile(
                    title: Text(food['name']),
                    subtitle: Text(
                        'Calories: ${food['calories']}, Protein: ${food['protein']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _saveSelectedFood(food);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
