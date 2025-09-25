import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../subscription/premium_content_wrapper.dart';
import '../subscription/subscription_detail_screen.dart';
import 'media_viewer_screen.dart';
import 'models/workout_plans.dart';

class ThemeConstants {
  static const primaryLight = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF818CF8);
  static const backgroundLight = Color(0xFFF8FAFC);
  static const backgroundDark = Color(0xFF0F172A);
  static const cardLight = Colors.white;
  static const cardDark = Color(0xFF1E293B);
  static const textLight = Color(0xFF334155);
  static const textDark = Color(0xFFF8FAFC);
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  VideoPlayerScreenState createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  late ChewieController _chewieController;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initializeVideoPlayerFuture = _controller.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _controller,
      autoPlay: true,
      looping: true,
    );
  }

  @override
  void dispose() {
    _chewieController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Player')),
      body: Center(
        child: FutureBuilder<void>(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Chewie(
                controller: _chewieController,
              );
            } else {
              return CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}

class VideoThumbnail extends StatelessWidget {
  final String videoUrl;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          color: Colors.black87,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        const Icon(
          Icons.play_circle_fill,
          size: 48,
          color: Colors.white70,
        ),
      ],
    );
  }
}

class SubscriptionManager {
  static Future<bool> isSubscribedToAuthor(String authorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc('${user.uid}_$authorId')
        .get();

    return doc.exists && doc.data()?['status'] == 'active';
  }
}

class WorkoutScreen extends StatefulWidget {
  final String planId;

  const WorkoutScreen({
    super.key,
    required this.planId,
  });

  @override
  WorkoutScreenState createState() => WorkoutScreenState();
}

class WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _difficulties = const ['beginner', 'intermediate', 'advanced'];

  List<WorkoutPlan> _workoutPlans = [];
  Set<String> _userWorkoutPlans = {};
  WorkoutPlan? _selectedWorkoutPlan;
  final Map<String, bool> _authorSubscriptions = {};

  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _difficulties.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    if (widget.planId.trim().isEmpty) {
      setState(() {
        _errors.add('Plan ID cannot be empty');
        _isLoading = false;
      });
      return;
    }
    _initialize();
  }

  void _addError(String error) {
    if (mounted) {
      setState(() {
        _errors.add(error);
      });
    }
  }

  Future<void> _initialize() async {
    try {
      // Only try to load specific plan if planId is not empty
      if (widget.planId.isNotEmpty) {
        await _loadWorkoutPlan(widget.planId);
      }

      await Future.wait([
        _fetchWorkoutPlans(_difficulties[0]),
        _fetchUserWorkoutPlans(),
      ]);
      await _fetchSubscriptionStatuses();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errors.add(e.toString());
        });
      }
    }
  }

  Future<void> _loadWorkoutPlan(String planId) async {
    if (planId.trim().isEmpty) {
      _addError('Invalid plan ID');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId.trim())
          .get();

      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Workout plan not found',
        );
      }

      if (mounted) {
        setState(() {
          _selectedWorkoutPlan = WorkoutPlan.fromFirestore(doc);
        });
      }
    } catch (e) {
      _addError(e.toString());
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchWorkoutPlans(_difficulties[_tabController.index]);
    }
  }

  Future<void> _fetchSubscriptionStatuses() async {
    for (var plan in _workoutPlans) {
      if (plan.isPremium) {
        final isSubscribed = await SubscriptionManager.isSubscribedToAuthor(plan.authorId);
        if (mounted) {
          setState(() {
            _authorSubscriptions[plan.authorId] = isSubscribed;
          });
        }
      }
    }
  }

  void showWorkoutPlanModal(WorkoutPlan workoutPlan) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _CustomTheme(isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workoutPlan.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (workoutPlan.isPremium)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        color: theme.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Premium',
                                        style: TextStyle(
                                          color: theme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildRatingBar(workoutPlan.averageRating),
                          const SizedBox(height: 24),
                          Text(
                            'Description',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            workoutPlan.description,
                            style: TextStyle(
                              color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.8),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          if (workoutPlan.mediaItems.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Workout Media',
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: workoutPlan.mediaItems.length,
                                itemBuilder: (context, index) {
                                  final media = workoutPlan.mediaItems[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: index != workoutPlan.mediaItems.length - 1 ? 12 : 0,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MediaViewerScreen(
                                                mediaItems: workoutPlan.mediaItems,
                                                initialIndex: index,
                                              ),
                                            ),
                                          ),
                                          child: media['type'] == 'video'
                                              ? VideoThumbnail(videoUrl: media['url'])
                                              : CachedNetworkImage(
                                            imageUrl: media['url'],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () {
                    Navigator.pop(context);  // Close modal first
                    _handleAddPlan();  // Then handle add plan
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(theme.textOnPrimary),
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Start Workout Plan',
                    style: TextStyle(
                      color: theme.textOnPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchWorkoutPlans(String difficulty) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('plans')
          .where('type', isEqualTo: 'workout')
          .where('difficulty', isEqualTo: difficulty)
          .where('status', isEqualTo: 'active')
          .get();

      if (mounted) {
        setState(() {
          _workoutPlans = snapshot.docs
              .map((doc) => WorkoutPlan.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      _addError(e.toString());
    }
  }

  Future<void> _fetchUserWorkoutPlans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workout_plan')
          .get();

      if (mounted) {
        setState(() {
          _userWorkoutPlans = snapshot.docs
              .map((doc) => doc.data()['plan_id'] as String?)
              .where((id) => id != null)
              .cast<String>()
              .toSet();
        });
      }
    } catch (e) {
      _addError(e.toString());
    }
  }

  Future<void> _handleAddPlan() async {
    if (_selectedWorkoutPlan == null) {
      _addError('No workout plan selected');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addError('Please sign in to add a workout plan');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await WorkoutRepository.addUserWorkoutPlan(user.uid, _selectedWorkoutPlan!);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _errors.add('Workout plan added successfully!'); // Use errors list for success messages too
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errors.add('Error adding workout plan: ${e.toString()}');
        });
      }
    }
  }

  Widget lockedContentPreview({
    required Widget child,
    required WorkoutPlan workoutPlan,
  }) {
    final isSubscribed = _authorSubscriptions[workoutPlan.authorId] ?? false;
    final shouldLock = workoutPlan.isPremium && !isSubscribed;

    return Stack(
      children: [
        child,
        if (shouldLock)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubscriptionDetailsScreen(
                        professionalId: workoutPlan.authorId,
                        professionalName: workoutPlan.authorName,
                      ),
                    ),
                  );
                },
                child: Container(
                  color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.5),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: Colors.amber, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Premium Content by ${workoutPlan.authorName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Subscribe to unlock',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void handleWorkoutPlanPress(WorkoutPlan workoutPlan) {
    final isSubscribed = _authorSubscriptions[workoutPlan.authorId] ?? false;

    if (workoutPlan.isPremium && !isSubscribed) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubscriptionDetailsScreen(
            professionalId: workoutPlan.authorId,
            professionalName: workoutPlan.authorName,
          ),
        ),
      );
    } else {
      // Set selected plan before showing modal
      setState(() => _selectedWorkoutPlan = workoutPlan);

      // Use selected plan for modal content
      if (_selectedWorkoutPlan != null) {
        showWorkoutPlanModal(_selectedWorkoutPlan!);
      }
    }
  }

Widget _buildWorkoutCard(WorkoutPlan plan, _CustomTheme theme) {
  final bool isEnrolled = _userWorkoutPlans.contains(plan.id);

  return GestureDetector(
    onTap: () => handleWorkoutPlanPress(plan),
    child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.coverImage.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaViewerScreen(
                      mediaItems: [
                        {'type': 'image', 'url': plan.coverImage},
                        ...plan.mediaItems
                      ],
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: plan.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                      if (plan.mediaItems.isNotEmpty)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${plan.mediaItems.length + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'By ${plan.authorName}',
                  style: TextStyle(
                    color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 179),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: TextStyle(
                    color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 204),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRatingBar(plan.averageRating),

                // Enrolled badge
                if (isEnrolled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Enrolled',
                          style: TextStyle(
                            color: theme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _CustomTheme(isDark);

    if (_errors.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          final errorMessage = _errors.join('\n');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3 * _errors.length),
            ),
          );
          setState(() => _errors.clear());
        }
      });
    }

    Widget mainContent = _isLoading
        ? _buildLoadingIndicator(theme)
        : _workoutPlans.isEmpty
        ? _buildEmptyState(_difficulties[_tabController.index], theme)
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workoutPlans.length,
      itemBuilder: (context, index) {
        final workoutPlan = _workoutPlans[index];
        final workoutCard = _buildWorkoutCard(workoutPlan, theme);

        return PremiumContentWrapper(
          isPremium: workoutPlan.isPremium,
          professionalId: workoutPlan.authorId,
          professionalName: workoutPlan.authorName,
          contentType: 'Workout',
          onSubscribePressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubscriptionDetailsScreen(
                  professionalId: workoutPlan.authorId,
                  professionalName: workoutPlan.authorName,
                ),
              ),
            );
          },
          child: workoutCard,
        );
      },
    );

    return Scaffold(
      backgroundColor: theme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(theme),
        ],
        body: mainContent,
      ),
    );
  }

  Widget _buildSliverAppBar(_CustomTheme theme) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: true,
      pinned: true,
      backgroundColor: theme.card,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Workout Plans',
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 0.8),
                    theme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: Icon(
                Icons.fitness_center,
                size: 200,
                color: theme.primary.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: theme.primary,
        labelColor: theme.primary,
        unselectedLabelColor: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.6),
        indicatorWeight: 3,
        tabs: [
          _buildTab('Beginner', Icons.directions_walk),
          _buildTab('Intermediate', Icons.directions_run),
          _buildTab('Advanced', Icons.sports_martial_arts),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRatingBar(double rating) {
    return Row(
      children: [
        ...List.generate(5, (index) {
          final color = index < rating ? Colors.amber : Colors.grey.withValues(red: 0, green: 0, blue: 0, alpha: 0.3);
          return Icon(Icons.star, size: 16, color: color);
        }),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(_CustomTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading workout plans...',
            style: TextStyle(
              color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String difficulty, _CustomTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No $difficulty workouts available',
            style: TextStyle(
              color: theme.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new workouts',
            style: TextStyle(
              color: theme.text.withValues(red: 0, green: 0, blue: 0, alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _CustomTheme {
  final bool isDark;
  final Color primary;
  final Color background;
  final Color card;
  final Color text;
  final Color textOnPrimary;
  final Color shadow;

  _CustomTheme(this.isDark)
      : primary = isDark ? ThemeConstants.primaryDark : ThemeConstants.primaryLight,
        background = isDark ? ThemeConstants.backgroundDark : ThemeConstants.backgroundLight,
        card = isDark ? ThemeConstants.cardDark : ThemeConstants.cardLight,
        text = isDark ? ThemeConstants.textDark : ThemeConstants.textLight,
        textOnPrimary = Colors.white,
        shadow = isDark ? Colors.black : Colors.grey;
}

