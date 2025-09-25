import 'dart:ui';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mime/mime.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:vitalize/screens/community/post_card.dart';
import 'package:vitalize/screens/subscription/subscription_detail_screen.dart';
import '../../constants/app_constant.dart';
import 'media_type.dart';

class MediaItem {
  final File file;
  final MediaType type;
  final String? thumbnailPath;

  MediaItem({
    required this.file,
    required this.type,
    this.thumbnailPath,
  });

  factory MediaItem.fromFile(File file, MediaType type, {String? thumbnailPath}) {
    return MediaItem(
      file: file,
      type: type,
      thumbnailPath: thumbnailPath,
    );
  }
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final List<MediaItem> _mediaItems = [];
  bool postIsPremium = false;
  bool userIsPremium = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<bool> _validateFileType(File file) async {
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null) return false;

    return [
      'image/jpeg',
      'image/png',
      'image/gif',
      'video/mp4',
      'video/quicktime'
    ].contains(mimeType.toLowerCase());
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    try {
      if (isVideo) {
        final XFile? video = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 2),
        );

        if (video != null) {
          final videoFile = File(video.path);
          final fileSize = await videoFile.length();
          if (fileSize > 50 * 1024 * 1024) {
            throw 'Video size must be less than 50MB';
          }

          setState(() {
            _mediaItems.add(MediaItem.fromFile(
              videoFile,
              MediaType.video,
            ));
          });
          await _initializeVideo(videoFile);
        }
      } else {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        );
        if (image != null) {
          final imageFile = File(image.path);
          if (!await _validateFileType(imageFile)) {
            throw 'Unsupported image format. Please use JPEG, PNG, or GIF.';
          }
          if (await imageFile.length() > 10 * 1024 * 1024) {
            throw 'Image size must be less than 10MB';
          }

          setState(() {
            _mediaItems.add(MediaItem.fromFile(
              imageFile,
              MediaType.image,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildMediaPreview() {
    if (_mediaItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _mediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = _mediaItems[index];
          return Stack(
            children: [
              Container(
                width: 200,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: mediaItem.type == MediaType.video
                      ? _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const Center(child: CircularProgressIndicator())
                      : Image.file(
                    mediaItem.file,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _mediaItems.removeAt(index);
                      if (mediaItem.type == MediaType.video) {
                        _videoController?.dispose();
                        _chewieController?.dispose();
                        _videoController = null;
                        _chewieController = null;
                      }
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _initializeVideo(File videoFile) async {
    try {
      _videoController = VideoPlayerController.file(videoFile);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        aspectRatio: _videoController!.value.aspectRatio,
        autoPlay: false,
        looping: false,
        showControls: true,
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load video.')),
        );
      }
    }
  }

  Future<List<Map<String, String>>> _uploadMediaItems(String userId, ScaffoldMessengerState messenger) async {
    final List<Map<String, String>> mediaUrls = [];

    for (final item in _mediaItems) {
      try {
        final String contentType = item.type == MediaType.video
            ? 'video/mp4'
            : 'image/jpeg';
        final String extension = item.type == MediaType.video ? '.mp4' : '.jpg';

        final fileName = '${AppConstants.storageBasePath}/${DateTime.now().millisecondsSinceEpoch}_${mediaUrls.length}$extension';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'timestamp': DateTime.now().toIso8601String(),
            }
        );

        final uploadTask = ref.putFile(item.file, metadata);

        uploadTask.snapshotEvents.listen(
                (snapshot) {
              if (mounted) {
                setState(() {
                  _uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
                });
              }
            },
            onError: (error) {
              throw Exception('Upload failed: $error');
            }
        );

        await uploadTask;
        final url = await ref.getDownloadURL();

        mediaUrls.add({
          'url': url,
          'type': item.type.name,
        });
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error uploading media: $e')),
          );
        }
        continue;
      }
    }
    return mediaUrls;
  }

  Future<void> _createPost(BuildContext context, String content) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (content.trim().isEmpty && _mediaItems.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please add some content or media to your post.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to create a post.')),
      );
      return;
    }

    try {
      final mediaUrls = await _uploadMediaItems(user.uid, messenger);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw 'User profile not found';
      }

      final userData = userDoc.data()!;

      await FirebaseFirestore.instance.collection('posts').add({
        'authorId': user.uid,
        'authorName': userData['name'] ?? 'Anonymous',
        'authorProfilePic': userData['profile_picture'] ?? 'assets/images/default-profile.png',
        'postContent': content.trim(),
        'mediaUrls': mediaUrls,  // Now storing as array of maps with url and type
        'isPremium': postIsPremium,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'commentsCount': 0,
      });

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        navigator.pop();

        setState(() {
          _mediaItems.clear();
          _videoController?.dispose();
          _chewieController?.dispose();
          _videoController = null;
          _chewieController = null;
          postIsPremium = false;
          _uploadProgress = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    }
  }

      @override
      void initState() {
        super.initState();
        _fetchUserPremiumStatus();
      }

      Future<void> _fetchUserPremiumStatus() async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            setState(() {
              userIsPremium = userDoc.data()?['isPremium'] ?? false;
            });
          }
        }
      }

      Future<void> _showCreatePostBottomSheet(BuildContext context) async {
        String postContent = '';

        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.black,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery
                        .of(context)
                        .viewInsets
                        .bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Create Post',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Write your post...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          onChanged: (value) => postContent = value,
                        ),
                        const SizedBox(height: 16),
                        _buildMediaPreview(),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        // Media preview code stays the same...
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.image, color: Colors.white),
                              onPressed: () => _pickMedia(ImageSource.gallery),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.video_library, color: Colors.white),
                              onPressed: () => _pickMedia(
                                  ImageSource.gallery, isVideo: true),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.camera_alt, color: Colors.white),
                              onPressed: () => _pickMedia(ImageSource.camera),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.videocam, color: Colors.white),
                              onPressed: () =>
                                  _pickMedia(ImageSource.camera, isVideo: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Add the Premium toggle switch
                        Row(
                          children: [
                            const Text(
                              'Premium Post',
                              style: TextStyle(color: Colors.white),
                            ),
                            Switch(
                              value: postIsPremium,
                              onChanged: (value) {
                                setState(() {
                                  postIsPremium = value;
                                });
                              },
                              activeColor: Colors.blue,
                              inactiveThumbColor: Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _createPost(context, postContent),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('Post'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      }

      Widget lockedContentPreview({
        required Widget child,
        required bool postIsPremium,
        required bool userIsPremium,
        required VoidCallback onLockTap,
      }) {
        final shouldLock = postIsPremium && !userIsPremium;

        return Stack(
          children: [
            child, // Display the main content
            if (shouldLock) // Overlay if content is locked
              Positioned.fill(
                child: GestureDetector(
                  onTap: onLockTap,
                  // Handle lock tap to navigate to subscription details
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withAlpha(128),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: Colors.amber, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'Premium Content',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: onLockTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                            child: const Text('Learn More'),
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

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: const Text(
              'Community',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          body: Stack(
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingShimmer(context);
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final post = snapshot.data!.docs[index];
                        final bool isPostPremium = post['isPremium'] ?? false;

                        return Column(
                          children: [
                            lockedContentPreview(
                              postIsPremium: isPostPremium,
                              userIsPremium: userIsPremium,
                              onLockTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubscriptionDetailsScreen(
                                      professionalId: post['authorId'],
                                      professionalName: post['authorName'],
                                    ),
                                  ),
                                );
                              },
                              child: PostCard(
                                post: post,
                                key: ValueKey(post.id),
                              ),
                            ),
                            const Divider(color: Colors.grey),
                          ],
                        );
                      },
                    ),
                  );
                },
              ), if (_uploadProgress > 0 && _uploadProgress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _uploadProgress / 100,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.blue),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () => _showCreatePostBottomSheet(context),
            child: const Icon(Icons.add),
          ),
        );
      }

      Widget _buildLoadingShimmer(BuildContext context) {
        return ListView.builder(
          itemCount: 3,
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[850]!,
              highlightColor: Colors.grey[700]!,
              child: Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 150,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: MediaQuery
                        .of(context)
                        .size
                        .width,
                    color: Colors.white,
                  ),
                ],
              ),
            );
          },
        );
      }

      Widget _buildEmptyState() {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 56,
                color: Colors.grey[700],
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
    }