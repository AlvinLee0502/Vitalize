import 'package:flutter/foundation.dart';
import '../meal_plan/models/user_profile.dart';
import '../meal_plan/models/meal_data.dart';

class MealProvider extends ChangeNotifier {
  Map<String, Map<String, MealData>> meals = {};
  UserProfile? userProfile;
  Map<String, double> totalInfo = {
    'calories': 0,
    'protein': 0,
    'carbs': 0,
    'fats': 0,
  };

  bool isLoading = false;
  bool isError = false;

  void setIsLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setIsError(bool value) {
    isError = value;
    notifyListeners();
  }

  void initMeals() {
    meals = {
      'breakfast': {},
      'lunch': {},
      'dinner': {},
      'snacks': {},
    };
    calculateTotalNutrition(notify: false);
  }

  List<String> get mealTypes => meals.keys.toList();

  void setUserProfile(UserProfile profile) {
    userProfile = profile;
    notifyListeners();
  }

  void addMeal(String mealType, String foodItem, MealData data) {
    if (!meals.containsKey(mealType)) {
      meals[mealType] = {};
    }
    meals[mealType]![foodItem] = data;
    calculateTotalNutrition();
    notifyListeners();
  }

  void removeMeal(String mealType, String foodItem) {
    meals[mealType]?.remove(foodItem);
    calculateTotalNutrition();
    notifyListeners();
  }

  void clearMeals() {
    meals.forEach((key, value) => value.clear());
    calculateTotalNutrition();
    notifyListeners();
  }

  void calculateTotalNutrition({bool notify = true}) {
    final totals = meals.values.fold<Map<String, double>>({
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fats': 0,
    }, (acc, mealItems) {
      for (var data in mealItems.values) {
        acc['calories'] = acc['calories']! + (data.calories ?? 0);
        acc['protein'] = acc['protein']! + (data.protein ?? 0);
        acc['carbs'] = acc['carbs']! + (data.carbs ?? 0);
        acc['fats'] = acc['fats']! + (data.fats ?? 0);
      }
      return acc;
    });

    totalInfo = totals;
    if (notify) notifyListeners();
  }

  // Getters for specific nutrients
  double getTotalCalories(String mealType) {
    return totalInfo['calories'] ?? 0.0;
  }

  double getTotalProtein(String mealType) {
    return totalInfo['protein'] ?? 0.0;
  }

  double getTotalCarbs(String mealType) {
    return totalInfo['carbs'] ?? 0.0;
  }

  double getTotalFats(String mealType) {
    return totalInfo['fats'] ?? 0.0;
  }
}

extension MealProviderExtension on MealProvider {
  double getTotalForMeal(String mealType, String nutrient) {
    if (!meals.containsKey(mealType)) return 0.0;

    return meals[mealType]!.values.fold<double>(0.0, (sum, meal) {
      switch (nutrient) {
        case 'calories':
          return sum + (meal.calories ?? 0);
        case 'protein':
          return sum + (meal.protein ?? 0);
        case 'carbs':
          return sum + (meal.carbs ?? 0);
        case 'fats':
          return sum + (meal.fats ?? 0);
        default:
          return sum;
      }
    });
  }
}