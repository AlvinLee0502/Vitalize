import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingApplicationScreen extends StatefulWidget {
  const PendingApplicationScreen({super.key});

  @override
  PendingApplicationScreenState createState() => PendingApplicationScreenState();
}

class PendingApplicationScreenState extends State<PendingApplicationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Applications'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('applications')
              .where('isHPApplicationPending', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final applications = snapshot.data?.docs ?? [];

            if (applications.isEmpty) {
              return const Center(child: Text('No pending applications found.'));
            }

            return ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final application = applications[index].data() as Map<String, dynamic>;

                return Card(
                  child: ListTile(
                    title: Text(application['email'] ?? 'Unknown Email'),
                    subtitle: Text('Application ID: ${applications[index].id}'),
                    trailing: ElevatedButton(
                      onPressed: () => _approveApplication(applications[index].id),
                      child: const Text('Approve'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _approveApplication(String applicationId) async {
    try {
      await _firestore.collection('applications').doc(applicationId).update({
        'hpApprovalStatus': 'approved',
        'isHPApplicationPending': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application approved successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving application: $e')),
      );
    }
  }
}
