import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../subscription/premium_content_wrapper.dart';
import '../subscription/subscription_detail_screen.dart';
import 'media_type.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final Function()? onLoaded;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.onLoaded,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: _videoController!.value.aspectRatio,
        autoPlay: false,
        looping: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
        // Improved buffering UI
        showControlsOnInitialize: false,
        showOptions: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 30),
                const SizedBox(height: 8),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: _initializeVideo,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      widget.onLoaded?.call();

    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            const Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white),
            ),
            TextButton(
              onPressed: _initializeVideo,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _chewieController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}

class MediaContent extends StatefulWidget {
  final String mediaUrl;
  final MediaType mediaType;
  final Function() onDoubleTap;
  final Widget likeAnimation;

  const MediaContent({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    required this.onDoubleTap,
    required this.likeAnimation,
  });

  @override
  State<MediaContent> createState() => _MediaContentState();
}

class _MediaContentState extends State<MediaContent> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    if (widget.mediaType.isVideo) {
      await _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.mediaUrl.isNotEmpty && widget.mediaUrl.toLowerCase().endsWith('.mp4')) {
      final uri = Uri.parse(widget.mediaUrl);
      try {
        _videoPlayerController = VideoPlayerController.networkUrl(uri);
        await _videoPlayerController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          autoPlay: false,
          looping: true,
          showControls: true,
          placeholder: Center(
            child: CircularProgressIndicator(
              color: Colors.grey[300],
            ),
          ),
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.grey[700]!,
          ),
        );

        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.mediaType.isVideo)
            VideoPlayerWidget(
              videoUrl: widget.mediaUrl,
              onLoaded: () {
                // Handle video loaded callback if needed
              },
            )
          else if (widget.mediaType.isImage)
            CachedNetworkImage(
              imageUrl: widget.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  color: Colors.grey[300],
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading media',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
            )
          else if (_chewieController != null)
            AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: Chewie(controller: _chewieController!),
            )
          else
            Center(
              child: CircularProgressIndicator(
                color: Colors.grey[300],
              ),
            ),
          widget.likeAnimation,
        ],
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final QueryDocumentSnapshot post;
  final Function(String)? onDeletePost;
  final Function(String, String)? onReportPost;

  const PostCard({
    super.key,
    required this.post,
    this.onDeletePost,
    this.onReportPost,
  });

  @override
  PostCardState createState() => PostCardState();
}

class PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late final Map<String, dynamic> _postData;
  late final AnimationController _likeAnimationController;
  late final Animation<double> _likeAnimation;
  final TextEditingController _commentController = TextEditingController();

  bool _isLiked = false;
  bool _isExpanded = false;
  bool _showComments = false;
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingComments = false;

  String get _authorName => _postData['authorName'] ?? 'Anonymous';
  String get _content => _postData['postContent'] ?? '';
  String get _timeAgo => timeago.format(
    (_postData['timestamp'] as Timestamp).toDate(),
  );
  bool get _isMonetized => _postData['healthProfessionalID'] != null;

  @override
  void initState() {
    super.initState();
    _postData = widget.post.data() as Map<String, dynamic>;

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeAnimation = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _checkIfLiked();
    _checkSubscription();
  }

  Widget _buildMediaContent() {
    final mediaUrls = _postData['mediaUrls'];
    if (mediaUrls == null || (mediaUrls as List).isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: (mediaUrls).map((mediaItem) {
        // Handle both string and map cases
        final url = mediaItem is Map ? mediaItem['url'] as String : mediaItem as String;
        final type = mediaItem is Map ? mediaItem['type'] as String :
        (url.toLowerCase().endsWith('.mp4') ? 'video' : 'image');

        return MediaContent(
          mediaUrl: url,
          mediaType: type == 'video' ? MediaType.video : MediaType.image,
          onDoubleTap: _handleDoubleTap,
          likeAnimation: _buildLikeAnimation(),
        );
      }).toList(),
    );
  }

  Widget _buildContent() {
    if (_content.isEmpty) return const SizedBox.shrink();

    Widget contentWidget = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$_authorName ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: _content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
          ),
          if (!_isExpanded && _content.length > 100)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = true),
              child: Text(
                'more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );

    return PremiumContentWrapper(
      isPremium: widget.post['isPremium'] ?? false,
      professionalId: widget.post['authorId'],
      professionalName: widget.post['authorName'],
      contentType: 'Post',

      blurSigma: 5.0,
      onSubscribePressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionDetailsScreen(
              professionalId: widget.post['authorId'],
              professionalName: widget.post['authorName'],
            ),
          ),
        );
      },
      child: contentWidget,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
                size: 24,
              ),
              onPressed: _likePost,
            ),
            IconButton(
              icon: const Icon(
                Icons.mode_comment_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _showComments = !_showComments;
                  if (_showComments) {
                    _fetchComments();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.send_outlined,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {},
            ),
            const Spacer(),
            if (_isMonetized)
              IconButton(
                icon: Icon(
                  _isSubscribed ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _toggleSubscription,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${(_postData['likes'] ?? 0).toString()} likes',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 8),
          child: Text(
            _timeAgo.toUpperCase(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final likedBy = List<String>.from(_postData['likedBy'] ?? []);
      if (mounted) {
        setState(() {
          _isLiked = likedBy.contains(user.uid);
        });
      }
    }
  }

  Future<void> _fetchComments() async {
    if (_loadingComments) return;

    setState(() {
      _loadingComments = true;
    });

    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      final comments = await Future.wait(
        commentsSnapshot.docs.map((doc) async {
          final data = doc.data();
          final authorSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['authorId'])
              .get();

          return {
            ...data,
            'id': doc.id,
            'authorName': authorSnapshot.data()?['displayName'] ?? 'Anonymous',
            'authorProfilePic': authorSnapshot.data()?['profilePic'] ?? '',
          };
        }),
      );

      if (mounted) {
        setState(() {
          _comments = comments;
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingComments = false;
        });
        _showSnackBar('Error loading comments: $e');
      }
    }
  }

  Future<void> _postComment(String content) async {
    if (content.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to comment');
      return;
    }

    try {
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id);

      await postRef.collection('comments').add({
        'content': content.trim(),
        'authorId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await postRef.update({
        'commentsCount': FieldValue.increment(1),
      });

      _commentController.clear();
      await _fetchComments();
    } catch (e) {
      _showSnackBar('Error posting comment: $e');
    }
  }

  Widget _buildCommentsSection() {
    if (!_showComments) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.grey),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _postComment(_commentController.text),
                child: const Text('Post'),
              ),
            ],
          ),
        ),
        if (_loadingComments)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              final comment = _comments[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(
                        comment['authorProfilePic'] ?? 'https://via.placeholder.com/150',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${comment['authorName']} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                TextSpan(
                                  text: comment['content'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(
                              (comment['timestamp'] as Timestamp).toDate(),
                            ),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
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
      ],
    );
  }

  Future<void> _checkSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _postData.toString().contains('healthProfessionalID')) {
      try {
        final subscriptionsRef = FirebaseFirestore.instance
            .collection('subscriptions')
            .doc(user.uid);
        final subscriptionDoc = await subscriptionsRef.get();

        if (subscriptionDoc.exists && mounted) {
          final subscribedHealthPros = List<String>.from(
              subscriptionDoc.data()?['healthProfessionalsSubscribed'] ?? []);
          setState(() {
            _isSubscribed = subscribedHealthPros.contains(_postData['authorId']);
          });
        }
      } catch (e) {
        debugPrint('Error checking subscription: $e');
      }
    }
  }

  Future<void> _deletePost() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .delete();

      widget.onDeletePost?.call(widget.post.id);

      if (!context.mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Post deleted successfully!')),
      );
    } catch (e) {
      if (!context.mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error deleting post: $e')),
      );
    }
  }

  Widget _buildHeader() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAuthor = currentUser?.uid == _postData['authorId'];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(
                _postData['authorProfilePic'] ?? 'https://via.placeholder.com/150'
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _authorName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            color: Colors.grey[900],
            itemBuilder: (BuildContext context) {
              return [
                if (isAuthor)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Post', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Report Post', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
              ];
            },
            onSelected: (String value) {
              if (value == 'delete') {
                _deletePost();
              } else if (value == 'report') {
                widget.onReportPost?.call(widget.post.id, _postData['authorId']);
              }
            },
          ),
        ],
      ),
    );
  }


  void _handleDoubleTap() {
    if (!_isLiked) {
      _likePost();
      _likeAnimationController..reset()..forward();
    }
  }

  Widget _buildLikeAnimation() {
    return ScaleTransition(
      scale: _likeAnimation,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _likeAnimationController.isAnimating ? 1 : 0,
        child: const Icon(
          Icons.favorite,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }

  Future<void> _likePost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final postRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id);

        if (_isLiked) {
          await postRef.update({
            'likes': FieldValue.increment(-1),
            'likedBy': FieldValue.arrayRemove([user.uid])
          });
        } else {
          await postRef.update({
            'likes': FieldValue.increment(1),
            'likedBy': FieldValue.arrayUnion([user.uid])
          });
          _likeAnimationController..reset()..forward();
        }
        if (mounted) {
          setState(() {
            _isLiked = !_isLiked;
          });
        }
      } catch (e) {
        _showSnackBar('Error updating like: $e');
      }
    }
  }

  Future<void> _toggleSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final subscriptionRef = FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid);
      final subscriptionDoc = await subscriptionRef.get();
      final authorId = _postData['authorId'];

      if (subscriptionDoc.exists) {
        final subscribedHealthPros = List<String>.from(
            subscriptionDoc.data()?['healthProfessionalsSubscribed'] ?? []);

        if (_isSubscribed) {
          subscribedHealthPros.remove(authorId);
        } else {
          subscribedHealthPros.add(authorId);
        }

        await subscriptionRef.set({
          'healthProfessionalsSubscribed': subscribedHealthPros
        });
      } else {
        await subscriptionRef.set({
          'healthProfessionalsSubscribed': [authorId]
        });
      }

      if (mounted) {
        setState(() {
          _isSubscribed = !_isSubscribed;
        });
      }
    } catch (e) {
      _showSnackBar('Error toggling subscription: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Colors.grey[900]!, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildContent(),
          _buildMediaContent(),
          _buildActionButtons(),
          _buildCommentsSection(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}