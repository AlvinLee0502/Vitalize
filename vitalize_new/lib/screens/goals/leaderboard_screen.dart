import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const LeaderboardScreen({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
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

  Widget _buildPodiumItem(String name, int points, Color color, double height, int rank) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
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
            color: color.withOpacity(0.1),
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
                overflow: TextOverflow.ellipsis,
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

  Widget _buildLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('users')
          .orderBy('totalPoints', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data?.docs ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final name = userData['name'] ?? 'Anonymous';
            final points = userData['totalPoints'] ?? 0;

            Color color;
            switch (index) {
              case 0:
                color = Colors.amber; // Gold
                break;
              case 1:
                color = Colors.grey.shade400; // Silver
                break;
              case 2:
                color = Colors.brown.shade300; // Bronze
                break;
              default:
                color = Colors.blue;
            }

            if (index < 3) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPodiumItem(
                  name,
                  points,
                  color,
                  100 - (index * 10),
                  index + 1,
                ),
              );
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Text('${index + 1}'),
              ),
              title: Text(name),
              subtitle: Text('$points points'),
              trailing: Icon(Icons.emoji_events, color: color),
            );
          },
        );
      },
    );
  }

  Widget _buildMyGoals() {
    final userId = widget.auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please sign in to view your goals'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('users')
          .doc(userId)
          .collection('userGoals')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final goals = snapshot.data?.docs ?? [];
        if (goals.isEmpty) {
          return const Center(child: Text('No goals found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index].data() as Map<String, dynamic>;
            final progress = goal['progress'] as double? ?? 0.0;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['title'] ?? 'Untitled Goal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(goal['description'] ?? ''),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).toInt()}% Complete'),
                    if (goal['points'] != null) ...[
                      const SizedBox(height: 8),
                      Text('${goal['points']} points'),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableGoals() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('goals')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final goals = snapshot.data?.docs ?? [];
        if (goals.isEmpty) {
          return const Center(child: Text('No available goals'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index].data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                title: Text(goal['title'] ?? 'Untitled Goal'),
                subtitle: Text(goal['description'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: () async {
                    final userId = widget.auth.currentUser?.uid;
                    if (userId != null) {
                      await widget.firestore
                          .collection('users')
                          .doc(userId)
                          .collection('userGoals')
                          .add({
                        'goalId': goals[index].id,
                        'title': goal['title'],
                        'description': goal['description'],
                        'points': goal['points'],
                        'progress': 0.0,
                        'startedAt': FieldValue.serverTimestamp(),
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Goal accepted!')),
                      );
                    }
                  },
                  child: const Text('Accept'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Goals & Rankings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'My Goals'),
            Tab(text: 'Available Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboard(),
          _buildMyGoals(),
          _buildAvailableGoals(),
        ],
      ),
    );
  }
}