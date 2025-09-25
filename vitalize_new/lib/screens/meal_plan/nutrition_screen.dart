import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:vitalize/screens/providers/meal_provider.dart';
import 'food_screen.dart';
import 'models/meal_data.dart';

class DateSelector extends StatelessWidget {
  final List<String> dates;
  final String selectedDate;
  final Function(String) onDateSelected;

  const DateSelector({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dates.map((date) {
          bool isSelected = date == selectedDate;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextButton(
              onPressed: () => onDateSelected(date),
              style: TextButton.styleFrom(
                backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
                foregroundColor: isSelected ? Colors.white : null,
              ),
              child: Text(DateFormat('EEE, MMM d').format(DateTime.parse(date))),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class NutritionChart extends StatelessWidget {
  final List<double> calories;
  final List<double> protein;
  final List<double> carbs;
  final List<double> fats;
  final List<String> daysOfWeek;
  final String selectedNutrient;

  const NutritionChart({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.daysOfWeek,
    required this.selectedNutrient,
  });

  @override
  Widget build(BuildContext context) {
    List<double> dataToPlot;
    switch (selectedNutrient) {
      case 'protein':
        dataToPlot = protein;
        break;
      case 'carbs':
        dataToPlot = carbs;
        break;
      case 'fats':
        dataToPlot = fats;
        break;
      default:
        dataToPlot = calories;
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < daysOfWeek.length) {
                    return Text(daysOfWeek[value.toInt()]);
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: dataToPlot.asMap().entries.map((e) =>
                  FlSpot(e.key.toDouble(), e.value)
              ).toList(),
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class MealNutritionCard extends StatelessWidget {
  final String mealType;
  final Map<String, MealData> mealData;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final Function(String, String) onDelete;
  final VoidCallback onAddMeal;

  const MealNutritionCard({
    super.key,
    required this.mealType,
    required this.mealData,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.onDelete,
    required this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mealType.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onAddMeal, // Trigger navigation to FoodScreen
                ),
              ],
            ),
            const Divider(),
            ...mealData.entries.map((entry) => ListTile(
              title: Text(entry.key),
              subtitle: Text(
                '${entry.value.calories?.toStringAsFixed(1)} kcal',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDelete(mealType, entry.key),
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Cal: ${totalCalories.toStringAsFixed(1)}'),
                Text('P: ${totalProtein.toStringAsFixed(1)}g'),
                Text('C: ${totalCarbs.toStringAsFixed(1)}g'),
                Text('F: ${totalFats.toStringAsFixed(1)}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NutrientSummary extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const NutrientSummary({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class MealList extends StatelessWidget {
  final MealProvider mealProvider;
  final Function(String, String) onDelete;

  const MealList({
    super.key,
    required this.mealProvider,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: mealProvider.meals.entries.map((entry) {
        final mealType = entry.key;
        final mealData = entry.value;

        return MealNutritionCard(
          mealType: mealType,
          mealData: mealData,
          totalCalories: mealProvider.getTotalCalories(mealType),
          totalProtein: mealProvider.getTotalProtein(mealType),
          totalCarbs: mealProvider.getTotalCarbs(mealType),
          totalFats: mealProvider.getTotalFats(mealType),
          onDelete: onDelete,
          onAddMeal: () => onAddMeal(context, mealType), // Pass mealType here
        );
      }).toList(),
    );
  }
}

void onAddMeal(BuildContext context, String mealType) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FoodScreen(mealType: mealType, selectedDate: '',), // Pass the mealType
    ),
  );
}

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  NutritionScreenState createState() => NutritionScreenState();
}

class NutritionScreenState extends State<NutritionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<String> weekDates = [];
  bool isLoading = true;
  bool showWeeklyGraph = false;

  List<String> daysOfWeek = [];
  List<double> calories = [];
  List<double> protein = [];
  List<double> carbs = [];
  List<double> fats = [];

  @override
  void initState() {
    super.initState();
    generateWeekDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealProvider>().initMeals();
      fetchMealLogs(selectedDate);
    });
  }

  void generateWeekDates() {
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    weekDates = List.generate(7, (index) {
      return DateFormat('yyyy-MM-dd').format(startOfWeek.add(Duration(days: index)));
    });
  }

  Future<void> fetchWeeklyNutritionData() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      Map<String, Map<String, double>> groupedData = {
        for (var date in weekDates)
          date: {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fats': 0.0}
      };

      QuerySnapshot mealLogsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_logs')
          .where('timestamp', isGreaterThanOrEqualTo: DateTime.parse(weekDates.first))
          .where('timestamp', isLessThanOrEqualTo: DateTime.parse(weekDates.last).add(const Duration(days: 1)))
          .get();

      for (var doc in mealLogsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp;
        final date = DateFormat('yyyy-MM-dd').format(timestamp.toDate());

        if (groupedData.containsKey(date)) {
          groupedData[date]!['calories'] = (groupedData[date]!['calories'] ?? 0.0) + ((data['calories'] as num?)?.toDouble() ?? 0.0);
          groupedData[date]!['protein'] = (groupedData[date]!['protein'] ?? 0.0) + ((data['protein'] as num?)?.toDouble() ?? 0.0);
          groupedData[date]!['carbs'] = (groupedData[date]!['carbs'] ?? 0.0) + ((data['carbs'] as num?)?.toDouble() ?? 0.0);
          groupedData[date]!['fats'] = (groupedData[date]!['fats'] ?? 0.0) + ((data['fats'] as num?)?.toDouble() ?? 0.0);
        }
      }

      if (mounted) {
        setState(() {
          daysOfWeek = weekDates.map((date) => DateFormat('EEE').format(DateTime.parse(date))).toList();
          calories = weekDates.map((date) => groupedData[date]!['calories']!).toList();
          protein = weekDates.map((date) => groupedData[date]!['protein']!).toList();
          carbs = weekDates.map((date) => groupedData[date]!['carbs']!).toList();
          fats = weekDates.map((date) => groupedData[date]!['fats']!).toList();
        });
      }
    } catch (e) {
      _logger.e('Error fetching weekly nutrition data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching weekly data: $e')),
        );
      }
    }
  }

  Future<void> fetchMealLogs(String date) async {
    if (!mounted) return;

    final mealProvider = context.read<MealProvider>();

    mealProvider.setIsLoading(true); // Start loading
    setState(() {
      isLoading = true;
      selectedDate = date;
    });

    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      DateTime parsedDate = DateTime.parse(date);
      DateTime startOfDay = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot mealLogsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_logs')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      if (!mounted) return;

      mealProvider.clearMeals();

      for (var doc in mealLogsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _logger.i('Document data: $data');

        if (data['mealType'] != null && (data['name'] is String || data['food'] is String)) {
          final name = data['name'] as String? ?? data['food'] as String;
          try {
            final mealData = MealData.fromJson(data);
            mealProvider.addMeal(data['mealType'], name, mealData);
          } catch (e) {
            _logger.e('Error parsing meal data: $e');
          }
        }
      }

      mealProvider.calculateTotalNutrition();
      await fetchWeeklyNutritionData();
    } catch (e) {
      _logger.e('Error fetching meal logs: $e');
      if (!mounted) return;

      mealProvider.setIsError(true); // Set error state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching meal logs: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        mealProvider.setIsLoading(false); // End loading
      }
    }
  }

  Future<void> handleDelete(String mealType, String foodItem) async {
    final mealProvider = context.read<MealProvider>();
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      WriteBatch batch = _firestore.batch();
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('meal_logs')
          .where('timestamp', isGreaterThanOrEqualTo: DateTime.parse(selectedDate))
          .where('timestamp', isLessThan: DateTime.parse(selectedDate).add(const Duration(days: 1)))
          .where('mealType', isEqualTo: mealType)
          .where('name', isEqualTo: foodItem)
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!mounted) return;

      mealProvider.removeMeal(mealType, foodItem);
      mealProvider.calculateTotalNutrition();
      await fetchWeeklyNutritionData();
    } catch (e) {
      _logger.e('Error deleting food item: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting food item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Dashboard'),
        actions: [
          IconButton(
            icon: Icon(showWeeklyGraph ? Icons.view_day : Icons.view_week),
            onPressed: () {
              setState(() {
                showWeeklyGraph = !showWeeklyGraph;
              });
            },
            tooltip: showWeeklyGraph ? 'Show daily view' : 'Show weekly view',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => fetchMealLogs(selectedDate),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateSelector(
                  dates: weekDates,
                  selectedDate: selectedDate,
                  onDateSelected: fetchMealLogs,
                ),
                const SizedBox(height: 16),
                if (showWeeklyGraph) ...[
                  NutritionChart(
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fats: fats,
                    daysOfWeek: daysOfWeek,
                    selectedNutrient: '',
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  MealList(
                    mealProvider: context.watch<MealProvider>(),
                    onDelete: handleDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
