import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalize/screens/admin/admin_edit_profile_screen.dart';
import 'package:vitalize/screens/admin/admin_screen.dart';
import 'package:vitalize/screens/bluetooth/ble_device_scan_screen.dart';
import 'package:vitalize/screens/bluetooth/scan/fitbit_cubit.dart';
import 'package:vitalize/screens/bluetooth/scan/health_stats_cubit.dart';
import 'package:vitalize/screens/jogging/walkscreen.dart';
import 'package:vitalize/screens/community/message_screen.dart';
import 'package:vitalize/screens/meal_plan/food_screen.dart';
import 'package:vitalize/screens/health_professionals/hp_meal_plan_screen.dart';
import 'package:vitalize/screens/meal_plan/nutrition_screen.dart';
import 'package:vitalize/screens/meal_plan/meal_plan_screen.dart';
import 'package:vitalize/screens/providers/goal_provider.dart';
import 'package:vitalize/screens/providers/meal_provider.dart';
import 'package:vitalize/screens/profile/forgot_password_screen.dart';
import 'package:vitalize/screens/profile/hp_application_screen.dart';
import 'package:vitalize/screens/health_professionals/hp_edit_profile_screen.dart';
import 'package:vitalize/screens/health_professionals/hp_screen.dart';
import 'package:vitalize/screens/admin/super_admin_dashboard.dart';
import 'package:vitalize/screens/profile/user_profile_screen.dart';
import 'package:vitalize/screens/signup/activity_level_screen.dart';
import 'package:vitalize/screens/signup/complete_profile_screen.dart';
import 'package:vitalize/screens/signup/first_time_user_screen.dart';
import 'package:vitalize/screens/signup/goal_screen.dart';
import 'package:vitalize/screens/signup/height_screen.dart';
import 'package:vitalize/screens/signup/signin_screen.dart';
import 'package:vitalize/screens/signup/signup_screen.dart';
import 'package:vitalize/screens/signup/weight_screen.dart';
import 'package:vitalize/screens/water_reminder/water_reminder.dart';
import 'package:vitalize/screens/workout/workout_screen.dart';
import 'package:vitalize/user_plans/user_plans_screen.dart';
import 'firebase_options.dart';
import 'package:vitalize/screens/bluetooth/homescreen.dart' as bluetooth;
import 'dart:async';
import 'package:vitalize/screens/community/community_screen.dart' as community;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:vitalize/screens/providers/workout_provider.dart';
import 'package:vitalize/screens/goals/goal_details_screen.dart';

class
NotificationProvider with ChangeNotifier {
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  Future<void> initialize() async {
    _notificationsPlugin ??= FlutterLocalNotificationsPlugin();
    notifyListeners();
  }

  FlutterLocalNotificationsPlugin? get notificationsPlugin => _notificationsPlugin;
}

class ThemeConstants {
  static const primaryLight = Color(0xFF2196F3);
  static const primaryDark = Color(0xFF64B5F6);
  static const backgroundLight = Color(0xFFF5F5F5);
  static const backgroundDark = Color(0xFF121212);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF1E1E1E);
  static const textLight = Colors.black87;
  static const textDark = Colors.white;
}

void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully: ${app.name}');
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
    FirebaseFirestore.instance.settings =
    const Settings(persistenceEnabled: true);
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => MealProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider(FirebaseFirestore.instance)),
          ChangeNotifierProvider(create: (_) => WorkoutProvider()),
          BlocProvider(create: (_) => FitbitCubit()),
          BlocProvider(create: (_) => HealthStatsCubit()),
        ],
        child: const MyApp(),
      ),
    );
  }

class HealthProfessionalRouteBuilder extends StatelessWidget {
  final Widget Function(String) screenBuilder;

  const HealthProfessionalRouteBuilder({required this.screenBuilder, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getHealthProfessionalID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('Not a health professional')));
        } else {
          return screenBuilder(snapshot.data!);
        }
      },
    );
  }

  Future<String?> _getHealthProfessionalID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.getIdToken(true);
      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['role'] == 'healthProfessional') {
          return userDoc.data()?['healthProfessionalID'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching healthProfessionalID: $e');
    }
    return null;
  }
}

final FirebaseFirestore firestore = FirebaseFirestore.instance;
final FirebaseAuth auth = FirebaseAuth.instance;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      routes: _buildRoutes(),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      ..._authRoutes(),
      ..._profileRoutes(),
      ..._mealPlanRoutes(),
      ..._bluetoothRoutes(),
      ..._communityRoutes(),
      ..._editProfileRoutes(),
    };
  }

  Map<String, WidgetBuilder> _authRoutes() {
    return {
      '/signup': (context) => const SignUpScreen(),
      '/signIn': (context) => const SignInScreen(),
      '/firstTimeUser': (context) => FirstTimeUserScreen(onComplete: () {  },),
      '/weight': (context) => const WeightScreen(),
      '/height': (context) => const HeightScreen(),
      '/goal': (context) => const GoalScreen(),
      '/activityLevel': (context) => const ActivityLevelScreen(),
      '/completeProfile': (context) => const CompleteProfileScreen(),
      '/forgotPassword': (context) => const ForgotPasswordScreen(),
    };
  }

  Map<String, WidgetBuilder> _profileRoutes() {
    return {
      '/hpDashboard': (context) =>
          HealthProfessionalRouteBuilder(
            screenBuilder: (healthProfessionalID) =>
                HealthProfessionalScreen(healthProfessionalID: healthProfessionalID),
          ),
      '/healthProfessionalApplication': (context) => const HpApplicationScreen(),
      '/superAdminDashboard': (context) => const SuperAdminDashboard(),
      '/AdminDashboardScreen': (context) => const AdminDashboardScreen(),
      '/userProfileDashboard': (context) => const UserProfileScreen(),
    };
  }

  Map<String, WidgetBuilder> _mealPlanRoutes() {
    return {
      '/createMealPlan': (context) => _healthProfessionalScreenBuilder(
        context,
            (healthProfessionalID) => CreateMealPlanScreen(healthProfessionalID: healthProfessionalID, mealPlanId: '', authorName: '' ,),
      ),
      '/mealPlans': (context) => const MealPlanScreen(),
      '/foodScreen': (context) => const FoodScreen(mealType: '', selectedDate: ''),
      '/nutritionScreen': (context) => const NutritionScreen(),
      '/workout': (context) => WorkoutScreen(planId: 'valid-plan-id',),
    };
  }

  Map<String, WidgetBuilder> _bluetoothRoutes() {
    return {
      '/bluetoothScan': (context) => const BleDeviceScanScreen(),
      '/bluetoothHomeScreen': (context) => const bluetooth.HomeScreen(),
      '/waterReminder': (context) => const WaterReminderScreen(),
      '/walkScreen': (context) => const WalkScreen(),
      '/userPlans': (context) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          return UserPlansScreen(userId: currentUser.uid);
        } else {
          return const Scaffold(
            body: Center(child: Text('User not logged in')),
          );
        }
      },
      '/goals' : (context) => GoalsScreen(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,),
    };
  }

  Map<String, WidgetBuilder> _communityRoutes() {
    return {
      '/communityScreen': (context) => const community.CommunityScreen(),
      //'/adminAnnouncement': (context) => const AdminCommunityScreen(),
      //'/createHealthPost': (context) => const CreateContentScreen(healthProfessionalID: ''),
      '/directMessages': (context) => const MessageScreen(healthProfessionalID: '',),
    };
  }

  Map<String, WidgetBuilder> _editProfileRoutes() {
    return {
      '/AdminEditProfileScreen': (context) => const AdminEditProfileScreen(adminID: '',),
      '/HpEditProfileScreen': (context) => const HpEditProfileScreen(healthProfessionalID: '',),
      '/UserProfileScreen': (context) => const UserProfileScreen(),
    };
  }

  Widget _healthProfessionalScreenBuilder(BuildContext context, Widget Function(String) screenBuilder) {
    return FutureBuilder<String?>(
      future: _getHealthProfessionalID(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('Error loading health professional data')));
        } else if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('Not a health professional')));
        } else {
          return screenBuilder(snapshot.data!);
        }
      },
    );
  }

  Future<String?> _getHealthProfessionalID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          bool isHealthProfessional = userDoc.data()?['role'] == 'healthProfessional';
          if (isHealthProfessional) {
            return userDoc.data()?['healthProfessionalID'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching healthProfessionalID: $e');
    }
    return null;
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _isFirstTimeUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstTimeUser') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _isFirstTimeUser(),
            builder: (context, isFirstTimeSnapshot) {
              if (isFirstTimeSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (isFirstTimeSnapshot.data == true) {
                return FirstTimeUserScreen(
                  onComplete: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isFirstTimeUser', false);
                },
                );
              } else {
                return const bluetooth.HomeScreen();
              }
            },
          );
        } else {
          // User not logged in
          return const SignInScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    debugPrint("Initializing app...");
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      debugPrint("Navigating to AuthWrapper...");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add your app logo or name here
            const FlutterLogo(size: 100),  // Replace with your app logo
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}