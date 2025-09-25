import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'models/workout_plans.dart';

class MediaViewerScreen extends StatelessWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = mediaItems[index];
          return MediaItemViewer(mediaItem: mediaItem);
        },
      ),
    );
  }
}

class MediaItemViewer extends StatefulWidget {
  final Map<String, dynamic> mediaItem;

  const MediaItemViewer({
    super.key,
    required this.mediaItem,
  });

  @override
  State<MediaItemViewer> createState() => _MediaItemViewerState();
}

class _MediaItemViewerState extends State<MediaItemViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItem['type'] == 'video') {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.mediaItem['url']),
    );
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Error: $errorMessage',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItem['type'] == 'video') {
      if (_chewieController == null) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      return Center(child: Chewie(controller: _chewieController!));
    } else if (widget.mediaItem['type'] == 'image') {
      return InteractiveViewer(
        child: Center(
          child: Image.network(
            widget.mediaItem['url'],
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Error loading image',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class MediaDisplay extends StatelessWidget {
  final Map<String, dynamic> mediaItem;
  final double height;
  final double width;
  final BoxFit fit;
  final bool showPlayIcon;

  const MediaDisplay({
    super.key,
    required this.mediaItem,
    this.height = 200,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.showPlayIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaContent(),
          if (mediaItem['type'] == 'video' && showPlayIcon)
            _buildPlayIcon(),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    if (mediaItem['type'] == 'video') {
      return VideoThumbnail(videoUrl: mediaItem['url']);
    } else if (mediaItem['type'] == 'image') {
      return CachedNetworkImage(
        imageUrl: mediaItem['url'],
        fit: fit,
        placeholder: (context, url) => _buildLoadingIndicator(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      );
    }
    return _buildErrorWidget();
  }

  Widget _buildPlayIcon() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(height: 8),
            Text(
              'Error loading media',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoThumbnail extends StatefulWidget {
  final String videoUrl;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoController();
  }

  Future<void> _initializeVideoController() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Seek to first frame for thumbnail
        await _controller!.seekTo(Duration.zero);
        // Ensure video is paused
        await _controller!.pause();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    return VideoPlayer(_controller!);
  }
}

class PrimaryMediaItem extends StatelessWidget {
  final Map<String, dynamic> mediaItem;
  final WorkoutPlan workoutPlan;

  const PrimaryMediaItem({
    super.key,
    required this.mediaItem,
    required this.workoutPlan,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaViewerScreen(
            mediaItems: [mediaItem],
            initialIndex: 0,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaItem['type'] == 'video')
              VideoThumbnail(videoUrl: mediaItem['url'])
            else if (mediaItem['type'] == 'image')
              Image.network(
                mediaItem['url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.error_outline, color: Colors.red),
                  );
                },
              ),
            if (mediaItem['type'] == 'video')
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 64,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaThumbnail extends StatelessWidget {
  final Map<String, dynamic> mediaItem;
  final WorkoutPlan workoutPlan;
  final VoidCallback onTap;

  const MediaThumbnail({
    super.key,
    required this.mediaItem,
    required this.workoutPlan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black.withOpacity(0.1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaItem['type'] == 'video')
              VideoThumbnail(videoUrl: mediaItem['url'])
            else if (mediaItem['type'] == 'image')
              Image.network(
                mediaItem['url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.error_outline, color: Colors.red),
                  );
                },
              ),
            if (mediaItem['type'] == 'video')
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 32,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

