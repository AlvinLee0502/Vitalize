import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_constant.dart';
import '../subscription/premium_content_wrapper.dart';
import '../subscription/subscription_detail_screen.dart';
import '../subscription/subscription_service.dart';
import 'models/meal_collection.dart';
import 'nutrition_screen.dart';
import 'food_screen.dart';
import 'models/meal_plan.dart';
import 'models/meal_data.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final Map<String, bool> _authorSubscriptions = {};
  bool _mounted = true;
  late Stream<Map<String, bool>> _subscriptionStream;

  @override
  void initState() {
    super.initState();
    _subscriptionStream = SubscriptionService.getUserSubscriptions();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _handlePlanTap(BuildContext context, MealPlan plan) async {
    if (!_mounted) return;

    final isSubscribed = _authorSubscriptions[plan.authorId] ?? false;

    if (plan.isPremium && !isSubscribed) {
      if (!_mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionDetailsScreen(
            professionalId: plan.authorId,
            professionalName: plan.authorName,
          ),
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final mealsSnapshot = await FirebaseFirestore.instance
          .collection('meals')
          .where('mealPlanId', isEqualTo: plan.id)
          .get();

      final meals = mealsSnapshot.docs.map((doc) => MealData.fromFirestore(doc)).toList();

      if (!_mounted) return;

      navigator.push(
        MaterialPageRoute(
          builder: (context) => MealPlanDetailsScreen(
            mealPlan: plan,
            meals: meals,
            isSubscribed: isSubscribed,
          ),
        ),
      );
    } catch (e) {
      if (!_mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error loading meals: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, bool>>(
      stream: _subscriptionStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final subscriptions = snapshot.data ?? {};

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Meal & Nutrition'),
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 0,
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Meal Plans'),
                  Tab(text: 'Nutrition'),
                  Tab(text: 'Quick Add'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMealPlansTab(subscriptions),
                const NutritionScreen(),
                FoodScreen(
                  mealType: 'snack',
                  selectedDate: DateTime.now().toString().split(' ')[0],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMealPlansTab(Map<String, bool> subscriptions) {
    return StreamBuilder<List<MealPlan>>(
      stream: MealPlanRepository.getActiveMealPlans(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mealPlans = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.kPadding),
          itemCount: mealPlans.length,
          itemBuilder: (context, index) {
            final plan = mealPlans[index];
            final isSubscribed = subscriptions[plan.authorId] ?? false;

            return PremiumContentWrapper(
              isPremium: plan.isPremium,
              professionalId: plan.authorId,
              professionalName: plan.authorName,
              contentType: 'Meal Plan',
              onSubscribePressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubscriptionDetailsScreen(
                      professionalId: plan.authorId,
                      professionalName: plan.authorName,
                    ),
                  ),
                );
              },
              child: MealPlanCard(
                mealPlan: plan,
                isSubscribed: isSubscribed,
                onTap: () => _handlePlanTap(context, plan),
              ),
            );
          },
        );
      },
    );
  }
}

class MealPlanCard extends StatelessWidget {
  final MealPlan mealPlan;
  final bool isSubscribed;
  final VoidCallback onTap;

  const MealPlanCard({
    required this.mealPlan,
    required this.isSubscribed,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mealPlan.imageUrl != null)
              CachedNetworkImage(
                imageUrl: mealPlan.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                const Icon(Icons.error),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mealPlan.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (mealPlan.isPremium)
                        const Icon(Icons.star, color: Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(mealPlan.description),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today,
                        label: '${mealPlan.date} days',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.local_fire_department,
                        label: '${mealPlan.averageCalories.round()} cal/day',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MealPlanDetailsScreen extends StatelessWidget {
  final MealPlan mealPlan;
  final List<MealData> meals;
  final bool isSubscribed;

  const MealPlanDetailsScreen({
    required this.mealPlan,
    required this.meals,
    required this.isSubscribed,
    super.key,
  });

  Future<void> _handleAddPlan(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {

      final userMealPlansRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mealPlans')
          .doc(mealPlan.id);

      await userMealPlansRef.set({
        'planId': mealPlan.id,
        'addedAt': FieldValue.serverTimestamp(),
        'name': mealPlan.name,
        'description': mealPlan.description,
        'authorId': mealPlan.authorId,
        'authorName': mealPlan.authorName,
        'isPremium': mealPlan.isPremium,
      });

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Meal plan added successfully!')),
      );
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error adding meal plan: $e')),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              mealPlan.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            background: mealPlan.imageUrl != null
                ? CachedNetworkImage(
              imageUrl: mealPlan.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.restaurant, size: 50),
              ),
            )
                : Container(
              color: Colors.grey[300],
              child: const Icon(Icons.restaurant, size: 50),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mealPlan.description,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.access_time,
                              label: '${mealPlan.date} days',
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.local_fire_department,
                              label: '${mealPlan.averageCalories} cal/day',
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.restaurant,
                              label: '${meals.length} meals',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Meals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        meals.isEmpty
            ? SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No meals available for this plan',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ),
        )
            : SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final mealData = meals[index];
              final mealCollection = MealCollection(
                name: mealData.name,
                description: mealData.description,
                calories: mealData.calories,
                protein: mealData.protein,
                carbs: mealData.carbs,
                fats: mealData.fats,
              );
              return MealCard(meal: mealCollection);
            },
            childCount: meals.length,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumContentWrapper(
        isPremium: mealPlan.isPremium,
        professionalId: mealPlan.authorId,
        professionalName: mealPlan.authorName,
        contentType: 'Meal Plan',
        onSubscribePressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubscriptionDetailsScreen(
                professionalId: mealPlan.authorId,
                professionalName: mealPlan.authorName,
              ),
            ),
          );
        },
        child: _buildContent(context),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
              onPressed: mealPlan.isPremium && !isSubscribed
                  ? null: () => _handleAddPlan(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Add to My Plans',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

