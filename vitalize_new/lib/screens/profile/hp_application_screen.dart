import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../health_professionals/hp_screen.dart';

class HpApplicationScreen extends StatefulWidget {
  const HpApplicationScreen({super.key});

  @override
  HpApplicationScreenState createState() => HpApplicationScreenState();
}

class HpApplicationScreenState extends State<HpApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  String additionalInfo = '';
  String specialty = '';
  bool _isLoading = false;
  String? _applicationStatus; // Tracks the application status
  bool _hasSubmittedApplication = false; // Tracks if the application is already submitted
  String? _healthProfessionalID; // Stores healthProfessionalID if approved

  @override
  void initState() {
    super.initState();
    _checkExistingApplication();
  }

  Future<void> _checkExistingApplication() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('applications').doc(user.uid).get();

        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['isHPApplicationPending'] == true) {
            setState(() {
              _hasSubmittedApplication = true;
              _applicationStatus = data['hpApprovalStatus'] ?? 'pending';
              _healthProfessionalID = data['healthProfessionalID'];
            });

            // Automatically navigate to HealthProfessionalScreen if approved
            if (_applicationStatus == 'approved' && _healthProfessionalID != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HealthProfessionalScreen(healthProfessionalID: _healthProfessionalID!),
                  ),
                );
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking application: $e')),
          );
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> submitApplication() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser; // Get the current user

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('applications').doc(user.uid).set({
          'isHPApplicationPending': true,
          'hpApprovalStatus': 'pending',
          'additionalInfo': additionalInfo,
          'specialty': specialty,
          'email': user.email ?? 'Unknown Email', // Use a fallback for email
          'userId': user.uid, // Store the user's UID
          'appliedAt': FieldValue.serverTimestamp(), // Save the timestamp
        }, SetOptions(merge: true)); // Ensure creation or update

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted successfully!')),
          );
          setState(() {
            _hasSubmittedApplication = true;
            _applicationStatus = 'pending';
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting application: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User is not authenticated.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply to be a Health Professional'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasSubmittedApplication)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application Status: ${_applicationStatus?.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_applicationStatus == 'pending')
                      const Text(
                        'Your application is currently under review. Please wait for approval.',
                        style: TextStyle(fontSize: 16),
                      ),
                    if (_applicationStatus == 'approved')
                      const Text(
                        'Congratulations! Your application has been approved.',
                        style: TextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              if (!_hasSubmittedApplication)
                Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Additional Information'),
                      onChanged: (value) => additionalInfo = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please provide some information about yourself.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Specialty'),
                      onChanged: (value) => specialty = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please specify your specialty.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                        if (_formKey.currentState!.validate()) {
                          submitApplication();
                        }
                      },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Application'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}