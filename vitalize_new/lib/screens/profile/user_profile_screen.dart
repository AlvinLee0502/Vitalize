import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  String _profileImageUrl = 'assets/images/default-profile.png';
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _userEmailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  Color _withAlpha(Color color, int alpha) {
    return Color.fromARGB(alpha, color.r.toInt(), color.g.toInt(), color.b.toInt());
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadNotificationSettings();
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
    // Show a dialog to choose language
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
    if (await canLaunchUrl(url as Uri)) {
      await launchUrl(url as Uri);
    } else {
      _showSnackBar('Could not open privacy policy.');
    }
  }

  Future<void> _navigateToHelpSupport() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          print('Retrieved profile data: $data'); // Debugging line
          setState(() {
            _userNameController.text = data?['name'] ?? 'John Doe';
            _userEmailController.text = data?['email'] ?? 'johndoe@example.com';
            final profilePicture = data?['profile_picture'];
            if (profilePicture != null && profilePicture.isNotEmpty) {
              _profileImageUrl = profilePicture;
            } else {
              _profileImageUrl = 'assets/images/default-profile.png';
            }
          });
        }
      } catch (e) {
        _showSnackBar('Error loading profile: $e');
      }
    }
  }

  Future<void> _uploadImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isLoading = true);
      final file = File(image.path);
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnackBar('No user is logged in.');
        setState(() => _isLoading = false);
        return;
      }

      final ref = _storage.ref().child('user_profiles/${user.uid}/profile_picture');
      try {
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        print('Image uploaded successfully, URL: $url'); // Debug line

        await _firestore.collection('users').doc(user.uid).set({
          'profile_picture': url,
        }, SetOptions(merge: true));

        setState(() {
          _profileImageUrl = url;
          print('Updated profile image URL: $_profileImageUrl'); // Debug line
        });
        _showSnackBar('Profile picture updated successfully!');
      } catch (e) {
        _showSnackBar('Error uploading image: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _saveUserProfileChanges() async {
    if (_userNameController.text.isEmpty || _userEmailController.text.isEmpty) {
      _showSnackBar('Name and email cannot be empty');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _userNameController.text,
          'email': _userEmailController.text,
          'profile_picture': _profileImageUrl,
        });
        _showSnackBar('Profile saved successfully!');
      } catch (e) {
        _showSnackBar('Error saving profile: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProfilePicture() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        final ref = _storage.ref().child('user_profiles/${user.uid}/profile_picture');
        await ref.delete();
        await _firestore.collection('users').doc(user.uid).update({'profile_picture': FieldValue.delete()});

        setState(() => _profileImageUrl = 'https://via.placeholder.com/150');
        _showSnackBar('Profile picture deleted successfully!');
      } catch (e) {
        _showSnackBar('Error deleting profile picture: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToHealthProfessionalApplication() {
    Navigator.pushNamed(context, '/healthProfessionalApplication');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveUserProfileChanges,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 80),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _uploadImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[800]!, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _withAlpha(Colors.black, 102),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[850],
                    child: ClipOval(
                      child: FadeInImage(
                        image: NetworkImage(_profileImageUrl),
                        placeholder: const AssetImage('assets/images/default-profile.png'),
                        imageErrorBuilder: (context, error, stackTrace) {
                          print('Image load error: $error'); // Debugging line
                          return Image.asset('assets/images/default-profile.png',
                              fit: BoxFit.cover);
                        },
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[900]!, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _deleteProfilePicture,
            child: const Text(
              'Remove Photo',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildTextField(
                controller: _userNameController,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
              Divider(height: 1, color: Colors.grey[700]),
              _buildTextField(
                controller: _userEmailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                leading:
                const Icon(Icons.notifications_outlined, color: Colors.grey),
                title:
                const Text('Notifications', style: TextStyle(color: Colors.white)),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) => _toggleNotifications(),
                  activeColor: Colors.blue,
                ),
              ),
              Divider(height: 1, color: Colors.grey[700]),
              _buildSettingTile(
                icon: Icons.language_outlined,
                title: 'Language',
                trailing: 'English',
                onTap: _changeLanguage,
              ),
              Divider(height: 1, color: Colors.grey[700]),
              _buildSettingTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy',
                onTap: _openPrivacyPolicy,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Join Healthcare Community',
                onTap: _navigateToHealthProfessionalApplication,
              ),
              Divider(height: 1, color: Colors.grey[700]),
              _buildSettingTile(
                icon: Icons.support_outlined,
                title: 'Help & Support',
                onTap: _navigateToHelpSupport,
              ),
              Divider(height: 1, color: Colors.grey[700]),
              _buildSettingTile(
                icon: Icons.logout,
                title: 'Logout',
                textColor: Colors.redAccent,
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/signIn');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? trailing,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing != null
          ? Text(trailing, style: TextStyle(color: Colors.grey[400]))
          : Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
