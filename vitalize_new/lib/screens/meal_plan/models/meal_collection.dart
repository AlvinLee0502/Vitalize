import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealCollection {
  final String name;
  final String description;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fats;
  final List<String>? images;

  MealCollection({
    required this.name,
    required this.description,
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.images,
  });

  factory MealCollection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealCollection(
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      calories: (data['calories'] as num?)?.toDouble(),
      protein: (data['protein'] as num?)?.toDouble(),
      carbs: (data['carbs'] as num?)?.toDouble(),
      fats: (data['fats'] as num?)?.toDouble(),
      images: (data['images'] as List<dynamic>?)?.cast<String>(), // Parse image URLs
    );
  }
}

class MealCard extends StatelessWidget {
  final MealCollection meal;

  const MealCard({super.key, required this.meal});

  void _showMealDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => MealDetailSheet(
          meal: meal,
          scrollController: scrollController,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showMealDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (meal.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            meal.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NutritionInfo(
                    icon: Icons.local_fire_department,
                    label: 'Calories',
                    value: '${meal.calories?.round()}',
                  ),
                  _NutritionInfo(
                    icon: Icons.food_bank,
                    label: 'Protein',
                    value: '${meal.protein?.round()}g',
                  ),
                  _NutritionInfo(
                    icon: Icons.grain,
                    label: 'Carbs',
                    value: '${meal.carbs?.round()}g',
                  ),
                  _NutritionInfo(
                    icon: Icons.opacity,
                    label: 'Fats',
                    value: '${meal.fats?.round()}g',
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

class MealDetailSheet extends StatefulWidget {
  final MealCollection meal;
  final ScrollController scrollController;

  const MealDetailSheet({
    required this.meal,
    required this.scrollController,
    super.key,
  });

  @override
  State<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends State<MealDetailSheet> {
  List<String> _mealImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMealImages();
  }

  Future<void> _fetchMealImages() async {
    try {
      final mealDoc = await FirebaseFirestore.instance
          .collection('meals')
          .where('name', isEqualTo: widget.meal.name)
          .get();

      if (mealDoc.docs.isNotEmpty) {
        final data = mealDoc.docs.first.data();
        setState(() {
          _mealImages = List<String>.from(data['images'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching meal images: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageGallery(),
                  _buildNutritionDetails(),
                  if (widget.meal.description.isNotEmpty) _buildDescription(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(128),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.meal.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_mealImages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('No images available'),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: _mealImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _mealImages[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionDetails() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nutrition Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _NutritionRow(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: widget.meal.calories!.round().toString(),
              ),
              _NutritionRow(
                icon: Icons.food_bank,
                label: 'Protein',
                value: '${widget.meal.protein?.round()}g',
              ),
              _NutritionRow(
                icon: Icons.grain,
                label: 'Carbs',
                value: '${widget.meal.carbs?.round()}g',
              ),
              _NutritionRow(
                icon: Icons.opacity,
                label: 'Fats',
                value: '${widget.meal.fats?.round()}g',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.meal.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _NutritionInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _NutritionRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
