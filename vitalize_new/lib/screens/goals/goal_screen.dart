import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../providers/goal_provider.dart';
import 'goal_details_screen.dart';

class GoalsList extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const GoalsList({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  State<GoalsList> createState() => _GoalsListState();
}

class _GoalsListState extends State<GoalsList> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> acceptChallenge(String goalId) async {
    final userId = widget.auth.currentUser?.uid;
    if (userId != null) {
      final userGoalRef = widget.firestore.collection('users').doc(userId).collection('userGoals');
      await userGoalRef.add({
        'goalId': goalId,
        'status': 'Pending',
        'acceptedAt': Timestamp.now(),
      });
    }
  }

  Widget _buildMediaPlayer(String mediaUrl, bool isVideo) {
    if (isVideo) {
      return FutureBuilder<VideoPlayerController>(
        future: Future.delayed(Duration(seconds: 1), () => VideoPlayerController.networkUrl(Uri.parse(mediaUrl))),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final controller = snapshot.data!;
          return Chewie(
            controller: ChewieController(
              videoPlayerController: controller,
              autoPlay: false,
              looping: true,
            ),
          );
        },
      );
    } else {
      return Image.network(mediaUrl);
    }
  }

  Stream<List<Map<String, dynamic>>> getActiveGoals() {
    return widget.firestore.collection('goals')
        .where('isActive', isEqualTo: true) // Assuming 'isActive' is a field indicating if the goal is active
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return {
        'goalId': doc.id,
        'goalTitle': doc['goalTitle'] ?? 'No title',
        'description': doc['description'] ?? 'No description',
        'mediaUrl': doc['mediaUrl'] ?? '',
        'isVideo': doc['isVideo'] ?? false,
      };
    }).toList());
  }

  Widget _buildCreatedGoalsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getActiveGoals(),  // Use getActiveGoals to fetch all active goals
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final activeGoals = snapshot.data ?? [];
        if (activeGoals.isEmpty) {
          return const Center(child: Text('No active goals found'));
        }

        return ListView.builder(
          itemCount: activeGoals.length,
          itemBuilder: (context, index) {
            final goal = activeGoals[index];
            return ListTile(
              title: Text(goal['goalTitle']),
              subtitle: Text(goal['description']),
              leading: _buildMediaPlayer(goal['mediaUrl'], goal['isVideo']),
              trailing: IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => acceptChallenge(goal['goalId']),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoalDetailsScreen(
                      goalId: goal['goalId'],
                      firestore: widget.firestore,
                      userId: widget.auth.currentUser?.uid ?? '',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> completeGoal(String goalId, int points) async {
    final userId = widget.auth.currentUser?.uid;
    if (userId != null) {
      final userRef = widget.firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final currentPoints = userDoc['totalPoints'] ?? 0;
      final newPoints = currentPoints + points;

      await userRef.update({
        'totalPoints': newPoints,
      });

      await widget.firestore.collection('goals').doc(goalId).update({
        'isCompleted': true,
      });
    }
  }

  Widget _buildPodiumItem(String name, int points, Color color, double height, int rank) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withAlpha(51),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.emoji_events, color: color, size: height * 0.25),
              Positioned(
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$points pts',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Fetch leaderboard data
  Stream<List<Map<String, dynamic>>> getLeaderboardData() {
    return widget.firestore.collection('leaderboard')
        .orderBy('points', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return {
        'name': doc['name'] ?? 'Unknown',
        'points': doc['points'] ?? 0,
        'rank': doc['rank'] ?? 0,
      };
    }).toList());
  }

  Widget _buildLeaderboard() {
    return StreamBuilder<List<Map<String, dynamic>>>( // Improved stream handling
      stream: getLeaderboardData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final leaderboardData = snapshot.data ?? [];
        if (leaderboardData.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        return SingleChildScrollView(
          child: Column(
            children: leaderboardData.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final data = entry.value;
              Color color;
              switch (rank) {
                case 1:
                  color = Color(0xFFFFD700); // Gold
                  break;
                case 2:
                  color = Color(0xFFC0C0C0); // Silver
                  break;
                case 3:
                  color = Color(0xFFCD7F32); // Bronze
                  break;
                default:
                  color = Colors.grey;
              }
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalDetailsScreen(
                        goalId: data['rank'].toString(),
                        firestore: widget.firestore,
                        userId: widget.auth.currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
                child: _buildPodiumItem(data['name'], data['points'], color, 80, rank),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildChallenges() {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (query) {
                  goalProvider.updateSearchQuery(query);
                },
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: DropdownButton<String>(
                value: goalProvider.filter,
                items: ['All', 'Completed', 'Pending']
                    .map(
                      (filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(filter),
                  ),
                )
                    .toList(),
                onChanged: (filter) {
                  goalProvider.updateFilter(filter!);
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.firestore.collection('goals').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }

                  final allGoals = snapshot.data?.docs ?? [];
                  final filteredGoals = allGoals.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final goalTitle = data['goalTitle'] ?? '';
                    return goalTitle.toLowerCase().contains(goalProvider.searchQuery.toLowerCase()) &&
                        (goalProvider.filter == 'All' ||
                            (goalProvider.filter == 'Completed' && data['isCompleted'] == true));
                  }).toList();

                  if (filteredGoals.isEmpty) {
                    return const Center(child: Text('No goals found'));
                  }

                  return ListView.builder(
                    itemCount: filteredGoals.length,
                    itemBuilder: (context, index) {
                      final goal = filteredGoals[index];
                      return _buildGoalItem(goal);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Build individual goal item for the list
  Widget _buildGoalItem(QueryDocumentSnapshot goal) {
    final data = goal.data() as Map<String, dynamic>;
    final goalTitle = data['goalTitle'] ?? 'No title';  // Provide a fallback value for null goalTitle
    final description = data['description'] ?? 'No description';  // Provide a fallback value for null description

    return ListTile(
      title: Text(goalTitle),
      subtitle: Text(description),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(
              goalId: goal.id,
              firestore: FirebaseFirestore.instance,
              userId: widget.auth.currentUser?.uid ?? '',  // Pass the current user ID
            ),
          ),
        );
      },
    );
  }

  // Build the drawer widget
  Widget buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Goals & Challenges'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => GoalsList(
                    firestore: FirebaseFirestore.instance,
                    auth: FirebaseAuth.instance,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Goals & Challenges',
          style: TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'My Challenges'),
            Tab(text: 'Created Goals'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboard(),
          _buildChallenges(),
          _buildCreatedGoalsTab(),
        ],
      ),
    );
  }
}