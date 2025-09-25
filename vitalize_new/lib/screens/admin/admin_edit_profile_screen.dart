import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AdminEditProfileScreen extends StatefulWidget {
  final String adminID;

  const AdminEditProfileScreen({super.key, required this.adminID});

  @override
  AdminEditProfileScreenState createState() => AdminEditProfileScreenState();
}

class AdminEditProfileScreenState extends State<AdminEditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _profilePictureUrl;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminID)
          .get();

      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _profilePictureUrl = data['profilePictureUrl'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching admin data: $e';
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        await _uploadProfileImage(imageFile);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      String filePath = 'admins/${widget.adminID}/profilePicture.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

      await storageRef.putFile(imageFile);
      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminID)
          .update({'profilePictureUrl': downloadUrl});

      setState(() {
        _profilePictureUrl = downloadUrl;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading profile image: $e';
      });
    }
  }

  Future<void> _saveProfileData() async {
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.adminID)
          .update({
        'name': _nameController.text,
        'email': _emailController.text,
      });
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving profile data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Admin Profile'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profilePictureUrl != null
                    ? NetworkImage(_profilePictureUrl!)
                    : null,
                child: _profilePictureUrl == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfileData,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
