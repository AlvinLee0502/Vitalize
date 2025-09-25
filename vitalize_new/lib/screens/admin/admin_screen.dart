import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../community/community_screen.dart';
import 'analytics/admin_analytics_screen.dart';
import 'admin_profile_screen.dart';
import 'analytics/admin_analytics_service.dart';
import '../goals/goal_management_screen.dart';
import 'hp_control_screen.dart';
import 'review_mealplan_screen.dart';
import 'review_workout_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AdminAnalyticsService _analyticsService = AdminAnalyticsService();
  late final List<Widget> _bottomNavigationScreens;

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF64B5F6);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF242424);
  static const Color darkTextColor = Color(0xFFE0E0E0);
  static const Color darkSecondaryTextColor = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _bottomNavigationScreens = [
      const AnalyticsDashboard(),
      const CommunityScreen(),
      HpControlScreen(analyticsService: _analyticsService),
      const AdminProfileScreen(),
    ];
  }

  void _onBottomNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  BoxDecoration get cardDecoration => BoxDecoration(
    color: darkCardColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        spreadRadius: 1,
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurfaceColor,
          elevation: 0,
        ),
        cardColor: darkCardColor,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            _bottomNavigationScreens[_selectedIndex],
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: darkSurfaceColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BottomNavigationBar(
                    currentIndex: _selectedIndex,
                    onTap: _onBottomNavigationTap,
                    backgroundColor: darkSurfaceColor,
                    selectedItemColor: primaryColor,
                    unselectedItemColor: darkSecondaryTextColor,
                    type: BottomNavigationBarType.fixed,
                    showSelectedLabels: true,
                    showUnselectedLabels: false,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.group_rounded),
                        label: 'Community',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.assignment),
                        label: 'Health Professionals',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: darkSurfaceColor,
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
                        child: Icon(Icons.admin_panel_settings, color: primaryColor, size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(
                  icon: Icons.local_hospital,
                  text: 'Health Professionals',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HpControlScreen(analyticsService: _analyticsService,)),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.fastfood_rounded,
                  text: 'Meal Plans',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MealPlansReviewScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.post_add_rounded,
                  text: 'Posts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CommunityScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.fitness_center_rounded,
                  text: 'Workouts',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WorkoutsReviewScreen()),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.flag_rounded,
                  text: 'Goals',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoalsManagementScreen(
                          firestore: FirebaseFirestore.instance,
                          auth: FirebaseAuth.instance,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.grey),
                _buildDrawerItem(
                  icon: Icons.logout,
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
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/signIn');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color textColor = darkTextColor,
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
