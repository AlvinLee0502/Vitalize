import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/help_screen.dart';

class HpEditProfileScreen extends StatefulWidget {
  final String healthProfessionalID;

  const HpEditProfileScreen({super.key, required this.healthProfessionalID});

  @override
  HpEditProfileScreenState createState() => HpEditProfileScreenState();
}

class HpEditProfileScreenState extends State<HpEditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _profilePictureUrl = 'https://via.placeholder.com/150';
  final ImagePicker _picker = ImagePicker();
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  Future<void> _uploadImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _isLoading = true);
      final file = File(image.path);

      try {
        // 1. Upload to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('users/${widget.healthProfessionalID}/profile_picture.jpg');

        final uploadTask = ref.putFile(file);

        // Wait for upload to complete and get download URL
        await uploadTask.whenComplete(() => null);
        final url = await ref.getDownloadURL();

        // 2. Verify the URL was obtained
        if (url.isEmpty) {
          throw Exception('Failed to get download URL');
        }

        // 3. Update Firestore document with the URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.healthProfessionalID)
            .update({
          'profile_picture': url,
        });

        // 4. Only update state if both operations succeeded
        setState(() => _profilePictureUrl = url);
        _showSnackBar('Profile picture updated successfully!');
      } catch (e) {
        _showSnackBar('Error uploading profile picture: $e');
        // Rollback storage upload if Firestore update failed
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('users/${widget.healthProfessionalID}/profile_picture.jpg');
          await ref.delete();
        } catch (deleteError) {
          // Ignore delete errors in rollback
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    setState(() => _isLoading = true);
    try {
      // 1. Remove from Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${widget.healthProfessionalID}/profile_picture.jpg');
      await ref.delete();

      // 2. Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.healthProfessionalID)
          .update({
        'profile_picture': 'https://via.placeholder.com/150',
      });

      // 3. Update local state
      setState(() => _profilePictureUrl = 'https://via.placeholder.com/150');
      _showSnackBar('Profile picture removed successfully.');
    } catch (e) {
      _showSnackBar('Error removing profile picture: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update the profile header to use the new remove function
  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _uploadImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(_profilePictureUrl),
                backgroundColor: Colors.grey[850],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _removeProfilePicture,
          child: const Text(
            'Remove Photo',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }


  Future<void> _saveProfileData() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar('Name cannot be empty');
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Updated to save in 'users' collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.healthProfessionalID)
          .update({
        'name': _nameController.text.trim(),
      });
      _showSnackBar('Profile updated successfully!');
    } catch (e) {
      _showSnackBar('Error saving profile data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = !_notificationsEnabled;
    });
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    _showSnackBar(_notificationsEnabled
        ? 'Notifications enabled.'
        : 'Notifications disabled.');
  }

  Future<void> _changeLanguage() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () {
                  _showSnackBar('Language set to English.');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Bahasa Melayu'),
                onTap: () {
                  _showSnackBar('Language set to Bahasa Melayu.');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPrivacyPolicy() async {
    const url = 'https://example.com/privacy-policy';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showSnackBar('Could not open privacy policy.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/signIn', (route) => false);
  }

  Future<void> _navigateToHelpSupport() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saveProfileData,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPersonalInformationSection(),
            const SizedBox(height: 24),
            _buildPreferencesSection(),
            const SizedBox(height: 24),
            _buildAccountSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInformationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const Divider(color: Colors.grey),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: InputBorder.none,
            ),
            enabled: false,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Notifications', style: TextStyle(color: Colors.white)),
            value: _notificationsEnabled,
            onChanged: (_) => _toggleNotifications(),
            activeColor: Colors.blue,
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.grey),
            title: const Text('Language', style: TextStyle(color: Colors.white)),
            onTap: _changeLanguage,
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.grey),
            title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
            onTap: _openPrivacyPolicy,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.support_outlined, color: Colors.grey),
            title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
            onTap: _navigateToHelpSupport,
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
