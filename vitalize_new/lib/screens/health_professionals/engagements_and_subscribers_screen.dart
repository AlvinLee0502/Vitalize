import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart' as charts;

class PlanEngagementScreen extends StatefulWidget {
  final String planId;
  final String healthProfessionalID;

  const PlanEngagementScreen({
    super.key,
    required this.planId,
    required this.healthProfessionalID,
  });

  @override
  State<PlanEngagementScreen> createState() => _PlanEngagementScreenState();
}

class _PlanEngagementScreenState extends State<PlanEngagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<DocumentSnapshot> _planStream;
  final DateFormat dateFormat = DateFormat('MMM d, y');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _planStream = FirebaseFirestore.instance
        .collection('plans')
        .doc(widget.planId)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Subscribers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSubscribersTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _planStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final planData = snapshot.data!.data() as Map<String, dynamic>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricsCards(planData),
              const SizedBox(height: 24),
              _buildEngagementGraph(planData),
              const SizedBox(height: 24),
              _buildRecentActivity(planData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsCards(Map<String, dynamic> planData) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Subscribers',
          planData['subscriberCount']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          'Total Engagements',
          planData['engagementCount']?.toString() ?? '0',
          Icons.trending_up,
          Colors.green,
        ),
        _buildMetricCard(
          'Active Days',
          _calculateActiveDays(planData['createdAt']).toString(),
          Icons.calendar_today,
          Colors.orange,
        ),
        _buildMetricCard(
          'Avg. Daily Engagement',
          _calculateDailyEngagement(
            planData['engagementCount'] ?? 0,
            planData['createdAt'],
          ).toStringAsFixed(1),
          Icons.assessment,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementGraph(Map<String, dynamic> planData) {
    // Here you would fetch and process engagement data over time
    // This is a placeholder for the actual implementation
    return const Card(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Text('Engagement graph will be shown here'),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(Map<String, dynamic> planData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('plan_activities')
                  .where('planId', isEqualTo: widget.planId)
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data!.docs;

                if (activities.isEmpty) {
                  return const Center(
                    child: Text('No recent activity'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(activity['type'] ?? 'Unknown Activity'),
                      subtitle: Text(
                        dateFormat.format(
                          (activity['timestamp'] as Timestamp).toDate(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('subscribedPlans', arrayContains: widget.planId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final subscribers = snapshot.data!.docs;

        if (subscribers.isEmpty) {
          return const Center(
            child: Text('No subscribers yet'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subscribers.length,
          itemBuilder: (context, index) {
            final subscriber = subscribers[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: subscriber['profileImage'] != null
                      ? NetworkImage(subscriber['profileImage'])
                      : null,
                  child: subscriber['profileImage'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(subscriber['name'] ?? 'Unknown User'),
                subtitle: Text(
                  'Subscribed since: ${dateFormat.format(
                    (subscriber['subscribedDate'] as Timestamp).toDate(),
                  )}',
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'message',
                      child: Text('Send Message'),
                    ),
                    const PopupMenuItem(
                      value: 'progress',
                      child: Text('View Progress'),
                    ),
                  ],
                  onSelected: (value) {
                    // Handle menu item selection
                    switch (value) {
                      case 'message':
                      // Implement messaging functionality
                        break;
                      case 'progress':
                      // Implement progress viewing functionality
                        break;
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _calculateActiveDays(Timestamp? createdAt) {
    if (createdAt == null) return 0;
    final now = DateTime.now();
    final created = createdAt.toDate();
    return now.difference(created).inDays + 1;
  }

  double _calculateDailyEngagement(int totalEngagements, Timestamp? createdAt) {
    if (createdAt == null) return 0;
    final activeDays = _calculateActiveDays(createdAt);
    return activeDays == 0 ? 0 : totalEngagements / activeDays;
  }
}