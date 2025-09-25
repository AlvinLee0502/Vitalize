import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../community/inbox_screen.dart';
import '../community/community_screen.dart';
import 'hp_meal_plan_screen.dart';
import 'hp_create_workout_plan.dart';
import 'detailed_statistics_screen.dart';
import 'hp_edit_profile_screen.dart';
import '../profile/manage_subscribers_screen.dart';
import '../profile/notification_screen.dart';
import '../profile/settings_screen.dart';

class HealthProfessionalScreen extends StatefulWidget {
  final String healthProfessionalID;

  const HealthProfessionalScreen(
      {super.key, required this.healthProfessionalID});

  @override
  HealthProfessionalScreenState createState() =>
      HealthProfessionalScreenState();
}

class HealthProfessionalScreenState extends State<HealthProfessionalScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF81C784);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF424242);
  static const Color secondaryTextColor = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _screens = [
      _buildDashboard(),
      CommunityScreen(),
      const InboxScreen(),
      HpEditProfileScreen(healthProfessionalID: widget.healthProfessionalID),
    ];
    initializeHealthProfessionalData();
  }

  Future<void> initializeHealthProfessionalData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.healthProfessionalID)
          .get();

      if (!docSnapshot.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.healthProfessionalID)
            .set({
          'name': 'New Professional',
          'role': 'healthProfessional',
          'revenue': 0.0,
          'subscriberCount': 0,
          'rating': 0.0,
          'completedSessions': 0,
        });
        print('Created new health professional document');
      }
    } catch (e) {
      print('Error initializing health professional data: $e');
    }
  }

  Widget _buildAnalyticsSection(double revenue, int subscriberCount) {
    final List<Map<String, dynamic>> revenueData = [
      {'month': 'Jan', 'amount': revenue * 0.7},
      {'month': 'Feb', 'amount': revenue * 0.8},
      {'month': 'Mar', 'amount': revenue * 0.85},
      {'month': 'Apr', 'amount': revenue * 0.9},
      {'month': 'May', 'amount': revenue * 0.95},
      {'month': 'Jun', 'amount': revenue},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Growth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: revenueData.length,
              itemBuilder: (context, index) {
                final double percentage = (revenueData[index]['amount'] as double) / revenue;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 30,
                        height: 150 * percentage,
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha((178 + (77 * percentage)).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        revenueData[index]['month'] as String,
                        style: const TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Plan Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailedStatisticsScreen(
                        healthProfessionalID: widget.healthProfessionalID,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics, color: primaryColor),
                label: const Text('View Details', style: TextStyle(color: primaryColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('workout_plans')
                .where('healthProfessionalID', isEqualTo: widget.healthProfessionalID)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const Center(child: Text('No plans found'));
              }

              int totalMealPlans = 0;
              int totalWorkoutPlans = 0;
              int totalEngagements = 0;

              for (var doc in snapshot.data!.docs) {
                final plan = doc.data() as Map<String, dynamic>;
                if (plan['type'] == 'meal') {
                  totalMealPlans++;
                } else {
                  totalWorkoutPlans++;
                }
                totalEngagements += (plan['engagementCount'] ?? 0) as int;
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Meal Plans',
                    totalMealPlans.toString(),
                    Icons.restaurant_menu,
                  ),
                  _buildStatCard(
                    'Workout Plans',
                    totalWorkoutPlans.toString(),
                    Icons.fitness_center,
                  ),
                  _buildStatCard(
                    'Engagements',
                    totalEngagements.toString(),
                    Icons.people,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: primaryColor, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlansSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('plans')
                .where('healthProfessionalID', isEqualTo: widget.healthProfessionalID)
                .where('status', isEqualTo: 'active')
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No active plans'),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final plan = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final docId = snapshot.data!.docs[index].id;

                  return Card(
                    elevation: 0,
                    color: Colors.grey[100],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        plan['type'] == 'meal' ? Icons.restaurant_menu : Icons.fitness_center,
                        color: primaryColor,
                      ),
                      title: Text(plan['name'] ?? 'Unnamed Plan'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Subscribers: ${plan['subscriberCount'] ?? 0}'),
                          Text('Engagements: ${plan['engagementCount'] ?? 0}'),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit Plan'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'stats',
                            child: Row(
                              children: [
                                Icon(Icons.analytics, size: 20),
                                SizedBox(width: 8),
                                Text('View Statistics'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete Plan', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              if (plan['type'] == 'meal') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateMealPlanScreen(
                                      healthProfessionalID: widget.healthProfessionalID,
                                      mealPlanId: docId, authorName: '',
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HpCreateWorkoutPlanScreen(
                                      healthProfessionalID: widget.healthProfessionalID,
                                      workoutPlanId: docId, authorName: '',
                                    ),
                                  ),
                                );
                              }
                              break;
                            case 'stats':
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlanStatisticsScreen(
                                    planId: docId,
                                    healthProfessionalID: widget.healthProfessionalID,
                                  ),
                                ),
                              );
                              break;
                            case 'delete':
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Plan'),
                                  content: const Text(
                                    'Are you sure you want to delete this plan? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('plans')
                                    .doc(docId)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Plan deleted successfully'),
                                  ),
                                );
                              }
                              break;
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.healthProfessionalID)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Center(child: Text('No data available.'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        if (data['role'] != 'healthProfessional') {
          return const Center(child: Text('Invalid user type'));
        }

        return Container(
          color: backgroundColor,
          child: RefreshIndicator(
            color: primaryColor,
            onRefresh: () async {
              await Future.wait([
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.healthProfessionalID)
                    .get(),
                FirebaseFirestore.instance
                    .collection('plans')
                    .where('healthProfessionalID', isEqualTo: widget.healthProfessionalID)
                    .get(),
                Future.delayed(const Duration(milliseconds: 500)),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(data['name'] ?? 'Health Professional'),
                  const SizedBox(height: 24),
                  _buildShortcutsSection(),
                  const SizedBox(height: 24),
                  _buildPlanStatistics(),
                  const SizedBox(height: 24),
                  _buildMetricsGrid(
                    (data['revenue'] ?? 0.0).toDouble(),
                    (data['subscriberCount'] ?? 0) as int,
                    (data['rating'] ?? 0.0).toDouble(),
                    (data['completedSessions'] ?? 0) as int,
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsSection(
                    (data['revenue'] ?? 0.0).toDouble(),
                    (data['subscriberCount'] ?? 0) as int,
                  ),
                  const SizedBox(height: 24),
                  _buildActivePlansSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection(String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withAlpha(230),
            child: Icon(Icons.person, size: 40, color: primaryColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 16, color: Colors.white.withAlpha(230),),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(healthProfessionalID: ''),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: _buildShortcutButton(
            'Create Meal Plan',
            Icons.restaurant_menu_rounded,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateMealPlanScreen(
                    healthProfessionalID: widget.healthProfessionalID, mealPlanId: '', authorName: '',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildShortcutButton(
            'Create Workout',
            Icons.fitness_center_rounded,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HpCreateWorkoutPlanScreen(
                    healthProfessionalID: widget.healthProfessionalID, workoutPlanId: '', authorName: '',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutButton(String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: textColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(double revenue, int subscriberCount, double rating, int completedSessions) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard('Revenue', '\$${revenue.toStringAsFixed(2)}', Icons.attach_money_rounded),
        _buildMetricCard('Subscribers', subscriberCount.toString(), Icons.people_rounded),
        _buildMetricCard('Rating', rating.toString(), Icons.star_rounded),
        _buildMetricCard('Sessions', completedSessions.toString(), Icons.calendar_today_rounded),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primaryColor, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceColor,
          foregroundColor: textColor,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Health Professional Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(healthProfessionalID: ''),
                  ),
                );
              },
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Community'),
                BottomNavigationBarItem(icon: Icon(Icons.message_rounded), label: 'Messages'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: primaryColor,
              unselectedItemColor: secondaryTextColor,
              backgroundColor: surfaceColor,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              elevation: 0,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: surfaceColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(Icons.person, color: primaryColor, size: 30),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Health Professional',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.healthProfessionalID}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.restaurant_menu_rounded,
              text: 'Create Meal Plan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateMealPlanScreen(
                    healthProfessionalID: widget.healthProfessionalID, mealPlanId: '', authorName: '',
                  ),
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.fitness_center_rounded,
              text: 'Create Workout Plan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HpCreateWorkoutPlanScreen(
                    healthProfessionalID: widget.healthProfessionalID, workoutPlanId: '', authorName: '',
                  ),
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.people_rounded,
              text: 'Manage Subscribers',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageSubscribersScreen(
                    healthProfessionalID: widget.healthProfessionalID,
                  ),
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.settings_rounded,
              text: 'Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(healthProfessionalID: ''),
                ),
              ),
            ),
            const Divider(color: Colors.grey),
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              text: 'Logout',
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (mounted){
                    Navigator.pushReplacementNamed(context, '/signIn');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color textColor = textColor,
    Color iconColor = primaryColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      onTap: onTap,
    );
  }
}