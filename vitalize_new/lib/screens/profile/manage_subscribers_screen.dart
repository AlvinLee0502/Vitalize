import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubscribersScreen extends StatefulWidget {
  final String healthProfessionalID;

  const ManageSubscribersScreen({super.key, required this.healthProfessionalID});

  @override
  _ManageSubscribersScreenState createState() => _ManageSubscribersScreenState();
}

class _ManageSubscribersScreenState extends State<ManageSubscribersScreen> {
  double totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  // Function to load total earnings from Firestore
  Future<void> _loadEarnings() async {
    try {
      // Fetch the total earnings from healthProfessional document
      DocumentSnapshot healthProfessionalDoc = await FirebaseFirestore.instance
          .collection('healthProfessionals')
          .doc(widget.healthProfessionalID)
          .get();

      setState(() {
        totalEarnings = healthProfessionalDoc['revenue']?.toDouble() ?? 0.0;
      });
    } catch (e) {
      print('Error loading earnings: $e');
    }
  }

  // Function to cash out earnings (e.g., request payout)
  Future<void> _cashOut() async {
    try {
      // Update Firestore with cash out request
      await FirebaseFirestore.instance.collection('cashouts').add({
        'healthProfessionalID': widget.healthProfessionalID,
        'amount': totalEarnings,
        'dateRequested': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Update revenue to 0 after cashing out
      await FirebaseFirestore.instance
          .collection('healthProfessionals')
          .doc(widget.healthProfessionalID)
          .update({'revenue': 0.0});

      // Reset total earnings
      setState(() {
        totalEarnings = 0.0;
      });

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash out requested successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting cash out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subscribers and Earnings'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display total earnings
            Text(
              'Total Earnings: \$${totalEarnings.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Button to initiate cash out
            ElevatedButton(
              onPressed: totalEarnings > 0 ? _cashOut : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Request Cash Out'),
            ),
            const SizedBox(height: 20),

            // Display list of subscribers
            const Text(
              'Subscribers:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('healthProfessionalID', isEqualTo: widget.healthProfessionalID)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final subscribers = snapshot.data?.docs ?? [];
                  if (subscribers.isEmpty) {
                    return const Center(child: Text('No subscribers found.'));
                  }

                  return ListView.builder(
                    itemCount: subscribers.length,
                    itemBuilder: (context, index) {
                      final subscriber = subscribers[index];
                      final subscriberName = subscriber['subscriberName'] ?? 'Unknown';
                      final subscriptionDate = (subscriber['subscriptionStartDate'] as Timestamp).toDate();

                      return ListTile(
                        title: Text(subscriberName),
                        subtitle: Text('Subscribed on: ${subscriptionDate.toLocal()}'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          // Handle subscriber tap if needed (e.g., view subscriber details)
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
