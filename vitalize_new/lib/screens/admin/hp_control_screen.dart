import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'analytics/admin_analytics_service.dart';

class HpControlScreen extends StatefulWidget {
  final AdminAnalyticsService analyticsService;

  const HpControlScreen({
    required this.analyticsService,
    super.key
  });

  @override
  HpControlScreenState createState() => HpControlScreenState();
}

class HpControlScreenState extends State<HpControlScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProfessionals = [];

  @override
  void initState() {
    super.initState();
    _fetchHealthProfessionals();
  }

  void _fetchHealthProfessionals() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'healthProfessional')
        .get();
    setState(() {
      _filteredProfessionals =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    });
  }

  void _filterProfessionals(String query) {
    if (query.isEmpty) {
      _fetchHealthProfessionals();
    } else {
      setState(() {
        _filteredProfessionals = _filteredProfessionals.where((professional) {
          final name = (professional['name'] ?? '').toLowerCase();
          final email = (professional['email'] ?? '').toLowerCase();
          return name.contains(query.toLowerCase()) ||
              email.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Health Professionals Control',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Applications'),
              Tab(icon: Icon(Icons.group), text: 'Health Professionals'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildApplicationsList(),
            _buildHealthProfessionalsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('applications')
          .where('isHPApplicationPending', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading applications.'));
        }

        final applications = snapshot.data?.docs ?? [];
        if (applications.isEmpty) {
          return const Center(child: Text('No pending applications found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application =
            applications[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  application['email'] ?? 'No Email',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Status: ${application['hpApprovalStatus'] ?? 'Pending'}'),
                    Text(
                        'Applied At: ${_formatTimestamp(application['appliedAt'])}'),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () =>
                      _approveApplication(applications[index].id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHealthProfessionalsScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterProfessionals,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: _filteredProfessionals.length,
            itemBuilder: (context, index) {
              final professional = _filteredProfessionals[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(
                    professional['name'] ?? 'Unknown Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: ${professional['email'] ?? 'Unknown Email'}'),
                      if (professional['approvedAsHealthProfessionalAt'] != null)
                        Text(
                            'Approved At: ${_formatTimestamp(professional['approvedAsHealthProfessionalAt'])}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () =>
                        _demoteProfessional(professional['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Demote'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, yyyy - h:mm a').format(timestamp.toDate());
    }
    return '';
  }

  Future<void> _approveApplication(String applicationId) async {
    try {
      final batch = _firestore.batch();

      final applicationRef = _firestore.collection('applications').doc(applicationId);
      final applicationData = (await applicationRef.get()).data();

      if (applicationData != null) {
        final userId = applicationData['userId'];
        final userEmail = applicationData['email'];

        batch.update(applicationRef, {
          'hpApprovalStatus': 'approved',
          'isHPApplicationPending': false,
          'approvedAt': FieldValue.serverTimestamp(),
        });

        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'role': 'healthProfessional',
          'approvedAsHealthProfessionalAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();

        // Create audit log for approval
        await widget.analyticsService.createAuditLog(
          'Approve Health Professional',
          {
            'email': userEmail,
            'userId': userId,
            'applicationId': applicationId,
            'action': 'approve',
            'timestamp': DateTime.now(),
          },
        );

        _fetchHealthProfessionals();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application approved successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving application: $e')),
      );
    }
  }

  Future<void> _demoteProfessional(String userId) async {
    print("Demote button clicked for user ID: $userId");
    try {
      // Get user data before demotion for audit log
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userEmail = userData?['email'];

      await _firestore.collection('users').doc(userId).update({'role': 'user'});

      // Create audit log for demotion
      await widget.analyticsService.createAuditLog(
        'Demote Health Professional',
        {
          'email': userEmail,
          'userId': userId,
          'action': 'demote',
          'timestamp': DateTime.now(),
        },
      );

      _fetchHealthProfessionals();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health professional demoted successfully.')),
      );
    } catch (e) {
      print("Error in demoting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error demoting health professional: $e')),
      );
    }
  }
}
