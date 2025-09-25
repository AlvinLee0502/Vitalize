import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Inbox',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              // Navigate to new message screen
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('messages')
            .where('participants', arrayContains: _auth.currentUser?.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final messages = snapshot.data?.docs ?? [];

          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index].data() as Map<String, dynamic>;
              final participants = message['participants'] as List;
              final otherParticipant = participants.firstWhere(
                    (id) => id != _auth.currentUser?.uid,
                orElse: () => null,
              );

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherParticipant).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  if (userSnapshot.hasError) {
                    return const ListTile(
                      title: Text('Error fetching user', style: TextStyle(color: Colors.red)),
                    );
                  }

                  final user = userSnapshot.data?.data() as Map<String, dynamic>?;

                  return InkWell(
                    onTap: () {
                      // Navigate to chat screen
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: user?['profilePictureUrl'] != null
                            ? NetworkImage(user?['profilePictureUrl'])
                            : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
                      ),
                      title: Text(
                        user?['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        message['lastMessage'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        _formatTimestamp(message['lastMessageTime']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return TimeOfDay.fromDateTime(date).format(context);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
