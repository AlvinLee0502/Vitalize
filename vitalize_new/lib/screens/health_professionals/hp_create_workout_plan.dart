import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class HpCreateWorkoutPlanScreen extends StatefulWidget {
  final String healthProfessionalID;
  final String workoutPlanId;
  final String authorName;

  const HpCreateWorkoutPlanScreen({
    super.key,
    required this.healthProfessionalID,
    required this.workoutPlanId,
    required this.authorName,
  });

  @override
  State<HpCreateWorkoutPlanScreen> createState() => _HpCreateWorkoutPlanScreenState();
}

class _HpCreateWorkoutPlanScreenState extends State<HpCreateWorkoutPlanScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool isPremium = false;
  bool _isLoading = false;
  bool _isUpdating = false;
  File? _coverImage;
  String? _existingCoverImageUrl;
  final List<File> _workoutMedia = [];
  final List<String> _existingMediaUrls = [];
  DifficultyLevel _difficulty = DifficultyLevel.beginner;

  @override
  void initState() {
    super.initState();
    if (widget.workoutPlanId.isNotEmpty) {
      _isUpdating = true;
      _loadExistingPlan();
    }
  }
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPlan() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.workoutPlanId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        isPremium = data['isPremium'] ?? false;
        _existingCoverImageUrl = data['cover_image'];
        _existingMediaUrls.addAll(List<String>.from(data['media_items'] ?? []));
        _difficulty = DifficultyLevel.values.firstWhere(
              (e) => e.name == (data['difficulty'] ?? 'beginner'),
          orElse: () => DifficultyLevel.beginner,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMediaItem(String mediaUrl) async {
    try {
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
      await ref.delete();

      // Update Firestore document
      setState(() {
        _existingMediaUrls.remove(mediaUrl);
      });

      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.workoutPlanId)
          .update({
        'media_items': _existingMediaUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media item deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting media: $e')),
        );
      }
    }
  }

  Future<void> _pickImage({bool isCover = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        if (isCover) {
          _coverImage = File(pickedFile.path);
        } else {
          _workoutMedia.add(File(pickedFile.path));
        }
      });
    }
  }

  Future<String?> _uploadImage(File image, String folder) async {
    try {
      final String fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': widget.healthProfessionalID,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(image, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitWorkoutPlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImage == null && _existingCoverImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a cover image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? coverImageUrl = _existingCoverImageUrl;
      if (_coverImage != null) {
        // Delete existing cover image if updating
        if (_existingCoverImageUrl != null) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(_existingCoverImageUrl!);
            await ref.delete();
          } catch (e) {
            debugPrint('Error deleting old cover image: $e');
          }
        }
        coverImageUrl = await _uploadImage(_coverImage!, 'workout_covers');
        if (coverImageUrl == null) throw Exception('Failed to upload cover image');
      }

      List<String> mediaUrls = [..._existingMediaUrls];
      for (var media in _workoutMedia) {
        final url = await _uploadImage(media, 'workout_media');
        if (url != null) mediaUrls.add(url);
      }

      final planData = {
        'name': _titleController.text,
        'authorName': widget.authorName,
        'description': _descriptionController.text,
        'type': 'workout',
        'difficulty': _difficulty.name,
        'isPremium': isPremium,
        'cover_image': coverImageUrl,
        'media_items': mediaUrls,
        'healthProfessionalID': widget.healthProfessionalID,
        'status': 'active',
      };

      if (_isUpdating) {
        // Update existing plan
        await FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.workoutPlanId)
            .update({
          ...planData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new plan
        await FirebaseFirestore.instance.collection('plans').add({
          ...planData,
          'createdAt': FieldValue.serverTimestamp(),
          'subscriberCount': 0,
          'engagementCount': 0,
          'isApproved': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isUpdating
                ? 'Workout plan updated successfully'
                : 'Workout plan created successfully'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isUpdating
                ? 'Failed to update plan: $error'
                : 'Failed to create plan: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdating ? 'Edit Workout Plan' : 'Create Workout Plan'),
        backgroundColor: Colors.purple,
        actions: _isUpdating
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Section
              Text('Cover Image',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildCoverImageSection(),
              const SizedBox(height: 24),

              // Media Section
              Text('Workout Media',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              _buildMediaSection(),
              const SizedBox(height: 24),

              // Title TextField
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Description TextField
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                value?.isEmpty ?? true ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),

              // Premium Toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout Plan Type',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        title: const Text('Premium Plan'),
                        value: isPremium,
                        onChanged: (value) =>
                            setState(() => isPremium = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Difficulty Level
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Difficulty Level',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ...DifficultyLevel.values.map((level) =>
                          RadioListTile<DifficultyLevel>(
                            title: Text(level.name.toUpperCase()),
                            value: level,
                            groupValue: _difficulty,
                            onChanged: (value) =>
                                setState(() => _difficulty = value!),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitWorkoutPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_isUpdating
                      ? 'Update Workout Plan'
                      : 'Create Workout Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(File image, bool isCover) {
    return Stack(
      children: [
        Container(
          height: isCover ? 200 : null,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                if (isCover) {
                  _coverImage = null;
                } else {
                  _workoutMedia.remove(image);
                }
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImagePreview(String imageUrl, bool isCover) {
    return Stack(
      children: [
        Container(
          height: isCover ? 200 : null,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              if (isCover) {
                setState(() => _existingCoverImageUrl = null);
              } else {
                _deleteMediaItem(imageUrl);
              }
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadPlaceholder(bool isCover) {
    return InkWell(
      onTap: () => _pickImage(isCover: isCover),
      child: Container(
        height: isCover ? 200 : null,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: isCover ? 48 : 32,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              isCover ? 'Add Cover Image' : 'Add Media',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isCover ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImageSection() {
    if (_coverImage != null) {
      return _buildImagePreview(_coverImage!, true);
    } else if (_existingCoverImageUrl != null) {
      return _buildNetworkImagePreview(_existingCoverImageUrl!, true);
    }
    return _buildImageUploadPlaceholder(true);
  }

  Widget _buildMediaSection() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _workoutMedia.length + _existingMediaUrls.length + 1,
      itemBuilder: (context, index) {
        if (index < _existingMediaUrls.length) {
          return _buildNetworkImagePreview(_existingMediaUrls[index], false);
        }
        if (index < _existingMediaUrls.length + _workoutMedia.length) {
          return _buildImagePreview(
              _workoutMedia[index - _existingMediaUrls.length], false);
        }
        return _buildImageUploadPlaceholder(false);
      },
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout Plan'),
        content:
        const Text('Are you sure you want to delete this plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _deletePlan();
    }
  }

  Future<void> _deletePlan() async {
    setState(() => _isLoading = true);
    try {
      // Delete cover image
      if (_existingCoverImageUrl != null) {
        final ref = FirebaseStorage.instance.refFromURL(_existingCoverImageUrl!);
        await ref.delete();
      }

      // Delete all media items
      for (var mediaUrl in _existingMediaUrls) {
        final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
        await ref.delete();
      }

      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.workoutPlanId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout plan deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
enum DifficultyLevel {
  beginner,
  intermediate,
  advanced
}