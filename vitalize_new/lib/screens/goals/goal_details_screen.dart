import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'leaderboard_screen.dart';

class GoalDetailsScreen extends StatefulWidget {
  final String goalId;
  final FirebaseFirestore firestore;
  final String userId;

  const GoalDetailsScreen({
    super.key,
    required this.goalId,
    required this.firestore,
    required this.userId,
  });

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String videoUrl) async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoPlayerController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      aspectRatio: 16 / 9,
    );
    setState(() {});
  }

  Widget _buildMediaWidget(String? mediaUrl, bool isVideo) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isVideo) {
      if (_chewieController == null) {
        _initializeVideo(mediaUrl);
        return const Center(child: CircularProgressIndicator());
      }
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    }
  }

  Future<void> _updateProgress() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating progress...'),
          duration: Duration(milliseconds: 500),
        ),
      );
    }

    try {
      // Fetch user goal document
      final userGoalRef = widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('userGoals')
          .doc(widget.goalId);

      final userGoalDoc = await userGoalRef.get();

      // If document doesn't exist, initialize it with default values
      if (!userGoalDoc.exists) {
        await userGoalRef.set({
          'completions': 0,
          'requiredCompletions': 5,  // Set a default value (or modify based on your logic)
          'progress': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Show a message indicating that the goal was initialized
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal initialized!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;  // Exit after initializing
      }

      // If document exists, proceed with the update
      final currentCompletions = userGoalDoc.data()?['completions'] ?? 0;
      final requiredCompletions = userGoalDoc.data()?['requiredCompletions'] ?? 1;

      final newCompletions = currentCompletions + 1;
      final newProgress = newCompletions / requiredCompletions;

      // Update the user goal document with new progress
      await userGoalRef.update({
        'completions': newCompletions,
        'progress': newProgress,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await HapticFeedback.mediumImpact();

      // Check if progress is complete
      if (newProgress >= 1.0) {
        // Fetch goal document to get points
        final goalDoc = await widget.firestore
            .collection('goals')
            .doc(widget.goalId)
            .get();

        if (!goalDoc.exists) {
          throw 'Goal document not found!';
        }

        final points = goalDoc.data()?['points'] ?? 0;

        // Update user's total points
        final userRef = widget.firestore.collection('users').doc(widget.userId);
        await widget.firestore.runTransaction((transaction) async {
          final userDoc = await transaction.get(userRef);
          final currentPoints = userDoc.data()?['totalPoints'] ?? 0;
          transaction.update(userRef, {
            'totalPoints': currentPoints + points,
          });
        });

        // Show completion dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Congratulations!'),
              content: Text('You\'ve completed all $requiredCompletions steps and earned $points points!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Show success message for progress update
        if (mounted) {
          final remaining = requiredCompletions - newCompletions;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Progress updated! $remaining more to go'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserGoal(BuildContext context) async {
    // Show confirmation dialog first
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Give Up Goal?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to give up this goal? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Give Up'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete the user goal
      await widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('userGoals')
          .doc(widget.goalId)
          .delete();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal removed from your list'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Goal Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            onPressed: () => _deleteUserGoal(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: widget.firestore.collection('goals').doc(widget.goalId).snapshots(),
        builder: (context, goalSnapshot) {
          if (goalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!goalSnapshot.hasData || !goalSnapshot.data!.exists) {
            return const Center(child: Text('Goal not found'));
          }

          final goalData = goalSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          return StreamBuilder<DocumentSnapshot>(
            stream: widget.firestore
                .collection('users')
                .doc(widget.userId)
                .collection('userGoals')
                .doc(widget.goalId)
                .snapshots(),
            builder: (context, userGoalSnapshot) {
              if (!userGoalSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final userGoalData = userGoalSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final progress = userGoalData['progress'] as double? ?? 0.0;
              final completions = userGoalData['completions'] as int? ?? 0;
              final requiredCompletions = userGoalData['requiredCompletions'] as int? ?? 1;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media content
                    if (goalData['mediaUrl'] != null)
                      _buildMediaWidget(
                        goalData['mediaUrl'],
                        goalData['mediaType'] == 'video',
                      ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      goalData['title'] ?? 'Untitled Goal',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Points
                    Row(
                      children: [
                        Icon(Icons.stars, color: Colors.amber[400]),
                        const SizedBox(width: 8),
                        Text(
                          '${goalData['points']} points',
                          style: TextStyle(color: Colors.amber[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      goalData['description'] ?? 'No description available',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),

                    // Progress section
                    Text(
                      'Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Completed $completions of $requiredCompletions times',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),

                    // Update progress button
                    if (progress < 1.0)
                      ElevatedButton(
                        onPressed: _updateProgress,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: Colors.blue,
                        ),
                        child: Text('Mark Day ${completions + 1} Complete'),
                      ),

                    if (progress >= 1.0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Challenge Completed!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GoalsScreen extends StatelessWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const GoalsScreen({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeaderboardScreen(
                    firestore: firestore,
                    auth: auth,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
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
            return const Center(child: Text('No goals available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index].data() as Map<String, dynamic>;

              return Card(
                color: Colors.grey[850],
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoalDetailsScreen(
                          goalId: goals[index].id,
                          firestore: firestore,
                          userId: auth.currentUser?.uid ?? '',
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (goal['mediaUrl'] != null)
                        Image.network(
                          goal['mediaUrl'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'] ?? 'Untitled Goal',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              goal['description'] ?? '',
                              style: const TextStyle(color: Colors.white70),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.stars, color: Colors.amber[400], size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${goal['points']} points',
                                  style: TextStyle(color: Colors.amber[400]),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GoalDetailsScreen(
                                          goalId: goals[index].id,
                                          firestore: firestore,
                                          userId: auth.currentUser?.uid ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('View Details'),
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
            },
          );
        },
      ),
    );
  }
}