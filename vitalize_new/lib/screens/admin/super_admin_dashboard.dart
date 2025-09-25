import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';
import '../notifications_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  SuperAdminDashboardState createState() => SuperAdminDashboardState();
}

class SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _addAdminController = TextEditingController();
  late final NotificationService _notificationService;

  late Widget _currentScreen;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF64B5F6);
  static const Color accentColor = Color(0xFF82B1FF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurfaceColor = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF242424);
  static const Color darkTextColor = Color(0xFFE0E0E0);
  static const Color darkSecondaryTextColor = Color(0xFFB0B0B0);

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(userId: _auth.currentUser!.uid);
    _currentScreen = _buildAnalyticsScreen(); // Set default screen
  }

  @override
  void dispose() {
    _addAdminController.dispose();
    super.dispose();
  }

  void _navigateToScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  BoxDecoration get cardDecoration => BoxDecoration(
    color: darkCardColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
            alpha: 51,
            red: 0,
            green: 0,
            blue: 0,
        ),
        spreadRadius: 1,
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Stream<DocumentSnapshot> getAnalyticsStream() {
    return _firestore.collection('analytics').doc('dashboard').snapshots();
  }

  Widget _buildAnalyticsScreen() {
    return StreamBuilder<DocumentSnapshot>(
      stream: getAnalyticsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        return Container(
          color: darkBackground,  // Updated from backgroundColor
          child: RefreshIndicator(
            color: primaryColor,
            backgroundColor: darkCardColor,  // Updated from Colors.white
            strokeWidth: 3,
            onRefresh: () async {
              try {
                await _firestore.collection('analytics').doc('dashboard').get();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Analytics refreshed'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: primaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to refresh: ${e.toString()}'),
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkTextColor,  // Updated from secondaryColor
                    ),
                  ),
                ),
                _buildAnalyticsTile(
                  'Pending Applications',
                  data['pendingApplications'],
                  Icons.person_add,
                ),
                _buildAnalyticsTile(
                  'Pending Posts',
                  data['pendingPosts'],
                  Icons.post_add,
                ),
                _buildAnalyticsTile(
                  'Total Meal Plans',
                  data['totalMealPlans'],
                  Icons.restaurant_menu,
                ),
                _buildAnalyticsTile(
                  'Total Workouts',
                  data['totalWorkouts'],
                  Icons.fitness_center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTile(String title, dynamic count, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(
                alpha: 26,
                red: accentColor.r,
                green: accentColor.g,
                blue: accentColor.b
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          (count ?? 0).toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  /// --- Health Professionals Screen ---
  Widget _buildHealthProfessionalsScreen() {
    return _buildGenericListWithActions(
      collection: 'healthProfessionals',
      title: 'Health Professionals',
      icon: Icons.medical_services,
      customAction: (docId, data) => _demoteHealthProfessional(docId),
    );
  }

  Future<void> _demoteHealthProfessional(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Demotion'),
        content: const Text('Are you sure you want to demote this health professional to a normal user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Demote'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Update the role to 'user'
        await _firestore.collection('users').doc(userId).update({'role': 'user'});

        // Log the action
        await logAction('Demote Health Professional', {'userId': userId});

        _showSnackBar('Health Professional demoted successfully.');
      } catch (e) {
        _showErrorDialog('Error', 'Failed to demote health professional: $e');
      }
    }
  }

  /// --- Combined Meal Plans and Workouts Screen ---
  Widget _buildCombinedMealPlansAndWorkoutsScreen() {
    return DefaultTabController(
      length: 2, // Two tabs: Meal Plans and Workouts
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Meal Plans'),
              Tab(text: 'Workouts'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMealPlansScreen(),
                _buildWorkoutsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reviewItem(String title, String details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(details.isNotEmpty ? details : 'No details provided.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
      _showSnackBar('Item deleted successfully from $collection.');
    } catch (e) {
      _showErrorDialog('Error', 'Failed to delete item: $e');
    }
  }

  Future<void> _sendWarning(String recipient) async {
    final messageController = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Warning'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(labelText: 'Message'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Confirm to send
            child: const Text('Send'),
          ),
        ],
      ),
    );
    // If user cancels, stop the process
    if (shouldSend != true) {
      return;
    }

    final message = messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Message cannot be empty.');
      return;
    }

    try {
      // Perform Firestore operation
      await _firestore.collection('inbox').add({
        'to': recipient,
        'from': _auth.currentUser?.email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Warning sent successfully.');
    } catch (e) {
      _showErrorDialog('Error', 'Failed to send warning: $e');
    }
  }

    /// --- Meal Plans Screen ---
  Widget _buildMealPlansScreen() {
    return _buildGenericListWithActions(
      collection: 'mealPlans',
      title: 'Meal Plans',
      icon: Icons.restaurant_menu,
      customAction: (docId, data) {
        _sendWarning(data['uploadedBy'] ?? 'Unknown');
      },
    );
  }

  /// --- Workouts Screen ---
  Widget _buildWorkoutsScreen() {
    return _buildGenericListWithActions(
      collection: 'workout_plans',
      title: 'Workout Plans',
      icon: Icons.fitness_center,
      customAction: (docId, data) {
        _sendWarning(data['uploadedBy'] ?? 'Unknown');
      },
    );
  }

  /// --- Posts Screen ---
  Widget _buildPostsScreen() {
    return _buildGenericListWithActions(
      collection: 'posts',
      title: 'Pending Posts',
      icon: Icons.post_add,
      customAction: (docId, data) {
        _sendWarning(data['uploadedBy'] ?? 'Unknown');
      },
    );
  }

  Widget _buildGenericListWithActions({
    required String collection,
    required String title,
    required IconData icon,
    void Function(String docId, Map<String, dynamic> data)? customAction,
  }) {
    return Container(
      color: darkBackground,  // Updated from backgroundColor
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(collection).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final items = snapshot.data?.docs ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(icon, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,  // Updated from secondaryColor
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, size: 64, color: darkSecondaryTextColor),
                      const SizedBox(height: 16),
                      Text(
                        'No $title Found',
                        style: const TextStyle(
                          fontSize: 18,
                          color: darkSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final data = items[index].data() as Map<String, dynamic>;
                    final docId = items[index].id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: cardDecoration,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          data['title'] ?? data['name'] ?? 'No Title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: darkTextColor,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data['details'] ?? data['email'] ?? 'No details available.',
                            style: const TextStyle(color: darkSecondaryTextColor),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              color: accentColor,
                              onPressed: () => _reviewItem(
                                data['title'] ?? 'No Title',
                                data['details'] ?? '',
                              ),
                            ),
                            if (customAction != null)
                              IconButton(
                                icon: const Icon(Icons.warning),
                                color: Colors.orange,
                                onPressed: () => customAction(docId, data),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red[400],
                                onPressed: () => _deleteItem(collection, docId),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// --- Admin Management Screen ---
  Widget _buildAdminManagementScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildAddAdminField(), // Improved add admin input
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').where('role', isEqualTo: 'admin').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final admins = snapshot.data?.docs ?? [];
              if (admins.isEmpty) {
                return const Center(child: Text('No admins found.'));
              }

              return ListView.builder(
                itemCount: admins.length,
                itemBuilder: (context, index) {
                  final data = admins[index].data() as Map<String, dynamic>;
                  final userId = admins[index].id; // Get the document ID
                  return Card(
                    child: ListTile(
                      title: Text(data['name'] ?? 'No Name'),
                      subtitle: Text(data['email'] ?? 'No Email'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _demoteAdmin(userId),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddAdminField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _addAdminController,
            decoration: InputDecoration(
              labelText: 'Enter User Email or Username',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _addAdminController.clear(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _addAdmin,
          child: const Text('Add Admin'),
        ),
      ],
    );
  }

  Future<void> _addAdmin() async {
    final input = _addAdminController.text.trim();
    if (input.isEmpty) {
      _showSnackBar('Please provide an email, user ID, or username.');
      return;
    }

    try {
      QuerySnapshot snapshot;
      if (input.contains('@')) {
        snapshot = await _firestore.collection('users').where('email', isEqualTo: input).get();
      } else {
        snapshot = await _firestore.collection('users').where('username', isEqualTo: input).get();
      }

      if (snapshot.docs.isEmpty) {
        _showSnackBar('User not found.');
        return;
      }

      final userDoc = snapshot.docs.first;
      await _firestore.collection('users').doc(userDoc.id).update({'role': 'admin'});

      await logAction('Add Admin', {'email': userDoc['email']});

      _showSnackBar('Admin added successfully.');
    } catch (e) {
      _showErrorDialog('Error', 'Error adding admin: $e');
    }
  }


  Future<void> _demoteAdmin(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Demotion'),
        content: const Text('Are you sure you want to remove admin privileges for this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Demote'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(userId).update({'role': 'user'});
        await logAction('Remove Admin', {'userId': userId});

        _showSnackBar('Admin removed successfully.');
      } catch (e) {
        _showErrorDialog('Error', 'Error removing admin: $e');
      }
    }
  }

  Widget _buildAuditLogsScreen() {
    return Container(
      color: darkBackground,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('auditLogs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Error loading audit logs.',
                style: TextStyle(color: darkTextColor),
              ),
            );
          }

          final logs = snapshot.data?.docs ?? [];

          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: darkSecondaryTextColor),
                  SizedBox(height: 16),
                  Text(
                    'No audit logs found',
                    style: TextStyle(
                      color: darkTextColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.history, color: primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Audit Logs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index].data() as Map<String, dynamic>;
                    final action = log['action'] ?? 'Unknown Action';
                    final performedBy = log['performedBy'] ?? 'Unknown User';
                    final timestamp = log['timestamp']?.toDate() ?? DateTime.now();
                    final details = log['details'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: cardDecoration,
                      child: ExpansionTile(
                        collapsedIconColor: primaryColor,
                        iconColor: primaryColor,
                        title: Text(
                          action,
                          style: const TextStyle(
                            color: darkTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'By: $performedBy\n${_formatTimestamp(timestamp)}',
                          style: const TextStyle(
                            color: darkSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(color: Colors.grey),
                                const Text(
                                  'Details:',
                                  style: TextStyle(
                                    color: darkTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (details is Map<String, dynamic>)
                                  ...details.entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${entry.key}: ${entry.value}',
                                      style: const TextStyle(
                                        color: darkSecondaryTextColor,
                                      ),
                                    ),
                                  ))
                                else if (details is List<dynamic>)
                                  ...details.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      item.toString(),
                                      style: const TextStyle(
                                        color: darkSecondaryTextColor,
                                      ),
                                    ),
                                  ))
                                else
                                  const Text(
                                    'No details available',
                                    style: TextStyle(
                                      color: darkSecondaryTextColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}/'
        '${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  Future<void> logAction(String action, Map<String, dynamic> details) async {
    try {
      await _firestore.collection('auditLogs').add({
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'performedBy': _auth.currentUser?.email,
      });
    } catch (e) {
      _showErrorDialog('Error', 'Failed to log action: $e');
    }
  }

  /// --- Profile Screen ---
  Widget _buildProfileScreen() {
    final user = _auth.currentUser;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (user != null)
            Text('Logged in as: ${user.email}', style: const TextStyle(fontSize: 16)),
          ElevatedButton(
            onPressed: _confirmLogout,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
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
      _logout();
    }
  }

  void _logout() {
    _auth.signOut();
    Navigator.pushReplacementNamed(context, '/signIn');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

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
        expansionTileTheme: const ExpansionTileThemeData(
          backgroundColor: darkCardColor,
          collapsedBackgroundColor: darkCardColor,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkSurfaceColor,
          selectedItemColor: primaryColor,
          unselectedItemColor: darkSecondaryTextColor,
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text(
            'Super Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: const [
            NotificationIconButton(),
            SizedBox(width: 8),
          ],
        ),
        drawer: _buildDrawer(),
        body: _currentScreen,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: darkSurfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: 51,
                    red: 0,
                    green: 0,
                    blue: 0
                ),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            backgroundColor: darkSurfaceColor,
            selectedItemColor: primaryColor,
            unselectedItemColor: darkSecondaryTextColor,
            type: BottomNavigationBarType.fixed,
            currentIndex: _getCurrentIndex(),
            onTap: (index) {
              switch (index) {
                case 0:
                  _navigateToScreen(_buildAnalyticsScreen());
                  break;
                case 1:
                  _navigateToScreen(_buildAdminManagementScreen());
                  break;
                case 2:
                  _navigateToScreen(_buildPostsScreen());
                  break;
                case 3:
                  _navigateToScreen(_buildProfileScreen());
                  break;
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
              BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
              BottomNavigationBarItem(icon: Icon(Icons.post_add), label: 'Posts'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  int _getCurrentIndex() {
    if (_currentScreen.runtimeType == _buildAnalyticsScreen().runtimeType) {
      return 0;
    } else if (_currentScreen.runtimeType == _buildAdminManagementScreen().runtimeType) {
      return 1;
    } else if (_currentScreen.runtimeType == _buildPostsScreen().runtimeType) {
      return 2;
    } else if (_currentScreen.runtimeType ==_buildProfileScreen().runtimeType) {
      return 3;
    }
    return 0;
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: darkSurfaceColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: primaryColor,
              ),
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
                    _auth.currentUser?.email ?? 'Super Admin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Super Admin',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: primaryColor),
              title: const Text('Analytics'),
              onTap: () => _navigateToScreen(_buildAnalyticsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.medical_services, color: primaryColor),
              title: const Text('Health Professionals'),
              onTap: () => _navigateToScreen(_buildHealthProfessionalsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center, color: primaryColor),
              title: const Text('Plans & Workouts'),
              onTap: () => _navigateToScreen(_buildCombinedMealPlansAndWorkoutsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: primaryColor),
              title: const Text('Audit Logs'),
              onTap: () => _navigateToScreen(_buildAuditLogsScreen()),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }
}
