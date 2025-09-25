import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserPlansScreen extends StatefulWidget {
  const UserPlansScreen({super.key, required this.userId});
  final String userId;

  @override
  UserPlansScreenState createState() => UserPlansScreenState();
}

class UserPlansScreenState extends State<UserPlansScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = false;
  final _scrollController = ScrollController();
  bool _showingCompletedPlans = false;
  QuerySnapshot? workoutSnapshot;
  QuerySnapshot? mealSnapshot;
  QuerySnapshot? completedSnapshot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    try {
      await _loadPlans();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? getPlanId(DocumentSnapshot doc, String type) {
    final data = doc.data() as Map<String, dynamic>;
    if (type == 'workout') {
      return doc.id;
    } else {
      return data['planId'] as String?;
    }
  }

  Future<void> _loadPlans() async {
    try {
      if (_showingCompletedPlans) {
        // Load completed plans
        completedSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('completed_plans')
            .orderBy('completedAt', descending: true)
            .get();
      } else {
        // Load active plans
        workoutSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('workout_plan')
            .get();

        mealSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('meal_plan')
            .get();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading plans. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPlanList(String type) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: StreamBuilder<QuerySnapshot>(
          stream: _showingCompletedPlans
              ? FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('completed_plans')
              .where('planType', isEqualTo: type)
              .orderBy('completedAt', descending: true)
              .snapshots()
              : type == 'workout'
              ? FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('workout_plan')
              .snapshots()
              : FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('meal_plan')
              .snapshots(),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState('Error loading plans');
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState('No ${type.toLowerCase()} plans saved yet!');
          }

          final planIds = snapshot.data!.docs
              .map((doc) => getPlanId(doc, type))
              .where((id) => id != null)
              .cast<String>()
              .toList();

          if (planIds.isEmpty) {
            return _buildEmptyState('No valid ${type.toLowerCase()} plans found');
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('plans')
                .where(FieldPath.documentId, whereIn: planIds)
                .snapshots(),
            builder: (context, plansSnapshot) {
              if (plansSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (plansSnapshot.hasError) {
                return _buildErrorState('Error loading plan details');
              }

              if (!plansSnapshot.hasData || plansSnapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No ${type.toLowerCase()} plans found');
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: plansSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final planDoc = plansSnapshot.data!.docs[index];
                  final planData = planDoc.data() as Map<String, dynamic>;

                  DocumentSnapshot? userPlanDoc;
                  if (!_showingCompletedPlans) {
                    try {
                      userPlanDoc = snapshot.data!.docs.firstWhere((doc) {
                        final userPlanId = getPlanId(doc, type);
                        return userPlanId == planDoc.id;
                      });
                    } catch (e) {
                      debugPrint('Warning: Could not find matching user plan for ${planDoc.id}');
                    }
                  }

                  return _PlanCard(
                    doc: planDoc,
                    planData: planData,
                    isWorkoutPlan: type == 'workout',
                    onDelete: () => _deletePlan(
                        context,
                        userPlanDoc?.id ?? planDoc.id,
                        type
                    ),
                    onComplete: _showingCompletedPlans ? null : () => _completePlan(planDoc.id),
                    isCompleted: _showingCompletedPlans,
                    completedAt: _showingCompletedPlans
                        ? (planData['completedAt'] as Timestamp?)
                        : null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _completePlan(String planId) async {
    try {
      final now = DateTime.now();

      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();

      if (!planDoc.exists) {
        throw Exception('Plan not found');
      }

      final planData = planDoc.data()!;

      final batch = FirebaseFirestore.instance.batch();

      final completedPlanRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('completed_plans')
          .doc();

      batch.set(completedPlanRef, {
        'planId': planId,
        'planType': planData['type'],
        'completedAt': now,
        'originalPlan': planData,
      });

      final activePlanQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('${planData['type']}_plan')
          .where('planId', isEqualTo: planId)
          .get();

      for (var doc in activePlanQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan completed!'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error completing plan'))
        );
      }
    }
  }

  Future<void> _deletePlan(BuildContext context, String planId, String planType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('${planType}_plan')
            .doc(planId)
            .delete();

        if (mounted) {
          scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Plan deleted successfully'))
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Error deleting plan'))
          );
        }
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 128),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 179),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 128),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _handleRefresh,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            actions: [
              IconButton(
                icon: Icon(_showingCompletedPlans ? Icons.history : Icons.check_circle_outline),
                onPressed: () {
                  setState(() {
                    _showingCompletedPlans = !_showingCompletedPlans;
                  });
                },
                tooltip: _showingCompletedPlans ? 'Current Plans' : 'Past Records',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _showingCompletedPlans ? "Past Records" : "My Plans",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
              tabs: const [
                Tab(icon: Icon(Icons.fitness_center), text: "Workouts"),
                Tab(icon: Icon(Icons.restaurant_menu), text: "Meals"),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPlanList('workout'),
            _buildPlanList('meal'),
          ],
        ),
      ),
      floatingActionButton: _showingCompletedPlans ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(
          context,
          _tabController.index == 0 ? '/workout' : '/mealPlans',
        ),
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? "Add Workout" : "Add Meal Plan"),
        elevation: 4,
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.doc,
    required this.planData,
    required this.isWorkoutPlan,
    required this.onDelete,
    this.onComplete,
    this.isCompleted = false,
    this.completedAt,
  });

  final DocumentSnapshot doc;
  final Map<String, dynamic> planData;
  final bool isWorkoutPlan;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;
  final bool isCompleted;
  final Timestamp? completedAt;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isWorkoutPlan) {
      _initializeFirstVideo();
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeFirstVideo() async {
    final mediaItems = widget.planData['mediaItems'] as List?;
    if (mediaItems != null && mediaItems.isNotEmpty) {
      final firstVideoItem = mediaItems.firstWhere(
            (item) => item['type'] == 'video',
        orElse: () => null,
      );
      if (firstVideoItem != null) {
        await _initializeVideo(firstVideoItem['url']);
      }
    }
  }

  Future<void> _initializeVideo(String videoUrl) async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await _videoPlayerController!.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: 16 / 9,
        autoPlay: false,
        looping: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 77),
        ),
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  Widget _buildMediaContent() {
    final mediaItems = widget.planData['mediaItems'] as List?;

    if (mediaItems == null || mediaItems.isEmpty) {
      // Fallback to coverImage if no media items
      return widget.planData['coverImage'] != null
          ? _buildCoverImage(widget.planData['coverImage'])
          : const SizedBox.shrink();
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Current media display
              _buildCurrentMedia(mediaItems[_currentMediaIndex]),

              // Navigation arrows if there are multiple items
              if (mediaItems.length > 1)
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: _currentMediaIndex > 0
                            ? () => setState(() {
                          _currentMediaIndex--;
                          if (mediaItems[_currentMediaIndex]['type'] == 'video') {
                            _initializeVideo(mediaItems[_currentMediaIndex]['url']);
                          }
                        })
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: _currentMediaIndex < mediaItems.length - 1
                            ? () => setState(() {
                          _currentMediaIndex++;
                          if (mediaItems[_currentMediaIndex]['type'] == 'video') {
                            _initializeVideo(mediaItems[_currentMediaIndex]['url']);
                          }
                        })
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Media indicators
        if (mediaItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                mediaItems.length,
                    (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentMediaIndex
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 77),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentMedia(Map<String, dynamic> mediaItem) {
    if (mediaItem['type'] == 'video') {
      if (_isVideoInitialized && _chewieController != null) {
        return Chewie(controller: _chewieController!);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else {
      return _buildCoverImage(mediaItem['url']);
    }
  }

  Widget _buildCoverImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.error_outline, size: 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            widget.isWorkoutPlan ? '/workout-detail' : '/meal-detail',
            arguments: {'docId': widget.doc.id, 'data': data},
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isWorkoutPlan) _buildMediaContent(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, data, colorScheme),
                  if (data['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      data['description'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 179),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildWorkoutDetails(context, data, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      Map<String, dynamic> data,
      ColorScheme colorScheme,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? 'Unnamed Plan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (data['authorName'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'By ${data['authorName']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 179),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!widget.isCompleted && widget.onComplete != null)
          TextButton.icon(
            onPressed: widget.onComplete,
            icon: Icon(Icons.check, color: colorScheme.primary),
            label: Text('Complete', style: TextStyle(color: colorScheme.primary)),
          ),
        if (!widget.isCompleted)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              _buildPopupMenuItem(
                Icons.delete_outline,
                'Delete',
                'delete',
                colorScheme,
                isDestructive: true,
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                widget.onDelete();
              }
            },
          ),
      ],
    );
  }

  Widget _buildWorkoutDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ColorScheme colorScheme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildDetailChip(
              context,
              Icons.fitness_center,
              data['difficulty'] ?? 'N/A',
              colorScheme.primary.withValues(alpha: 26),
              colorScheme.primary,
            ),
            if (data['isPremium'] == true) ...[
              const SizedBox(width: 8),
              _buildDetailChip(
                context,
                Icons.star,
                'Premium',
                colorScheme.secondary.withValues(alpha: 26),
                colorScheme.secondary,
              ),
            ],
          ],
        ),
        if (data['averageRating'] != null && data['averageRating'] > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.star,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                data['averageRating'].toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 179),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem(
      IconData icon,
      String text,
      String value,
      ColorScheme colorScheme, {
        bool isDestructive = false,
      }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive
                ? colorScheme.error
                : colorScheme.onSurface.withValues(alpha: 179),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isDestructive ? colorScheme.error : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(
      BuildContext context,
      IconData icon,
      String label,
      Color backgroundColor,
      Color foregroundColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
