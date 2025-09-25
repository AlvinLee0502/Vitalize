import 'package:cloud_firestore/cloud_firestore.dart';

class MealData {
  final String name;
  final String description;
  final String? usdaId;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final List<String>? images;

  MealData({
    required this.name,
    required this.description,
    this.usdaId,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.images,
  }) : assert(calories >= 0, 'Calories must be non-negative'),
        assert(protein >= 0, 'Protein must be non-negative'),
        assert(carbs >= 0, 'Carbs must be non-negative'),
        assert(fats >= 0, 'Fats must be non-negative');

  factory MealData.fromJson(Map<String, dynamic> json) {
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return MealData(
      name: json['name'] ?? 'Unknown Meal',
      description: json['description'] ?? '',
      usdaId: json['usdaId'],
      calories: safeDouble(json['calories']),
      protein: safeDouble(json['protein']),
      carbs: safeDouble(json['carbs']),
      fats: safeDouble(json['fats']),
      images: (json['images'] as List<dynamic>?)?.cast<String>(),
    );
  }

  factory MealData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealData.fromJson(data);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'usdaId': usdaId,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'images': images,
    };
  }

  MealData copyWith({
    String? name,
    String? description,
    String? usdaId,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    List<String>? images,
  }) {
    return MealData(
      name: name ?? this.name,
      description: description ?? this.description,
      usdaId: usdaId ?? this.usdaId,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      images: images ?? this.images,
    );
  }
}