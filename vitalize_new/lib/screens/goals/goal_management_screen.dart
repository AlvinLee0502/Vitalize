import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GoalsManagementScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const GoalsManagementScreen({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  State<GoalsManagementScreen> createState() => _GoalsManagementScreenState();
}

class _GoalsManagementScreenState extends State<GoalsManagementScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = widget.auth.currentUser;
    if (user != null) {
      final doc = await widget.firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isAdmin = doc.exists && doc.data()?['role'] == 'admin';
        });
      }
    }
  }

  Future<void> _handleMediaUpload() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    final XFile? result = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (BuildContext bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Upload Image'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null && mounted) {
                  setState(() => _selectedMedia = image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Upload Video'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                if (video != null && mounted) {
                  setState(() => _selectedMedia = video);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      _showCreateGoalDialog();
    }
  }

  Future<String?> _uploadMediaToStorage(XFile media) async {
    try {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = media.path.split('.').last;
      final String mediaType = extension == 'mp4' ? 'videos' : 'images';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('goals/$mediaType/$fileName.$extension');

      await storageRef.putFile(File(media.path));
      return await storageRef.getDownloadURL();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error uploading media: $e');
      }
      return null;
    }
  }

  Future<void> _deleteGoal(String goalId, String? mediaUrl) async {
    try {
      await widget.firestore.collection('goals').doc(goalId).delete();
      if (mediaUrl != null) {
        await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
      }
      _showSnackBar('Goal deleted successfully');
    } catch (e) {
      _showSnackBar('Error deleting goal: $e');
    }
  }

  Future<bool> _createGoal(String title, String description, int points, int requiredCompletions) async {
    if (title.isEmpty || description.isEmpty || points <= 0 || requiredCompletions <= 0) {
      _showSnackBar('All fields are required and must be positive numbers');
      return false;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl;
      String? mediaType;

      if (_selectedMedia != null) {
        mediaUrl = await _uploadMediaToStorage(_selectedMedia!);
        mediaType = _selectedMedia!.path.endsWith('.mp4') ? 'video' : 'image';
      }

      await widget.firestore.collection('goals').add({
        'title': title,
        'description': description,
        'points': points,
        'requiredCompletions': requiredCompletions,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'createdBy': widget.auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      if (mounted) {
        _showSnackBar('Goal created successfully');
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editGoal(String goalId, String title, String description, int points, int requiredCompletions, XFile? media) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final updates = <String, dynamic>{
        'title': title,
        'description': description,
        'points': points,
        'requiredCompletions': requiredCompletions,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (media != null) {
        final mediaUrl = await _uploadMediaToStorage(media);
        if (mediaUrl != null) {
          updates['mediaUrl'] = mediaUrl;
          updates['mediaType'] = media.path.endsWith('.mp4') ? 'video' : 'image';
        }
      }

      await widget.firestore.collection('goals').doc(goalId).update(updates);

      if (!mounted) return;
      _showSnackBar('Goal updated successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error updating goal: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateGoalDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final pointsController = TextEditingController();
    final completionsController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Create Challenge', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: _buildInputDecoration('Title'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: _buildInputDecoration('Description'),
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: _buildInputDecoration('Points'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: completionsController,
                    decoration: _buildInputDecoration('Required Days to Complete'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'How many days to complete this challenge?',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedMedia != null)
                Text(
                  'Media selected: ${_selectedMedia!.name}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ElevatedButton.icon(
                onPressed: _handleMediaUpload,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _selectedMedia = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
              final goal = await _createGoal(
                titleController.text,
                descController.text,
                int.tryParse(pointsController.text) ?? 0,
                int.tryParse(completionsController.text) ?? 1,
              );
              if (goal && mounted) {
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalDialog(String goalId, Map<String, dynamic> goalData) {
    final titleController = TextEditingController(text: goalData['title']);
    final descController = TextEditingController(text: goalData['description']);
    final pointsController = TextEditingController(text: goalData['points'].toString());
    final completionsController = TextEditingController(text: goalData['requiredCompletions']?.toString() ?? '1');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Edit Challenge', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: _buildInputDecoration('Title'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: _buildInputDecoration('Description'),
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: _buildInputDecoration('Points'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: completionsController,
                    decoration: _buildInputDecoration('Required Days to Complete'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'How many days to complete this challenge?',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_selectedMedia != null)
                Text(
                  'Media selected: ${_selectedMedia!.name}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ElevatedButton.icon(
                onPressed: _handleMediaUpload,
                icon: const Icon(Icons.attach_file),
                label: const Text('Add Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _selectedMedia = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
              await _editGoal(
                goalId,
                titleController.text,
                descController.text,
                int.tryParse(pointsController.text) ?? 0,
                int.tryParse(completionsController.text) ?? 1,
                _selectedMedia,
              );
              if (mounted) {
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('You do not have permission to access this page.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateGoalDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.firestore.collection('goals').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data!.docs;

          if (goals.isEmpty) {
            return const Center(child: Text('No goals found'));
          }

          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index].data() as Map<String, dynamic>;
              final goalId = goals[index].id;
              final mediaUrl = goal['mediaUrl'] as String?;

              return ListTile(
                title: Text(
                  goal['title'] as String? ?? 'Untitled',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${goal['points']} pts - ${goal['requiredCompletions']} days\n${goal['description']}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditGoalDialog(goalId, goal);
                    } else if (value == 'delete') {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Goal'),
                          content: const Text('Are you sure you want to delete this goal? This action cannot be undone.'),
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

                      if (shouldDelete == true) {
                        await _deleteGoal(goalId, mediaUrl);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white30),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.blue[700]!),
      ),
    );
  }

  @override
  void dispose() {
    _selectedMedia = null;
    super.dispose();
  }
}
