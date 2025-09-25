import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class MessageScreen extends StatefulWidget {
  final String healthProfessionalID;  // Health professional ID passed from outside the widget

  const MessageScreen({super.key, required this.healthProfessionalID});

  @override
  MessageScreenState createState() => MessageScreenState();
}

class MessageScreenState extends State<MessageScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _sendMessage() async {
    String messageText = _controller.text.trim();

    if (messageText.isNotEmpty) {
      try {
        String senderID = _auth.currentUser?.uid ?? '';

        Timestamp timestamp = Timestamp.now();

        await _firestore.collection('messages').add({
          'senderID': senderID,
          'receiverID': widget.healthProfessionalID,
          'message': messageText,
          'timestamp': timestamp,
        });

        _controller.clear();
      } on FirebaseException catch (e) {
        _showErrorDialog('Error: ${e.message}');
      } on PlatformException catch (e) {
        _showErrorDialog('Platform error: ${e.message}');
      } catch (e) {
        _showErrorDialog('An unexpected error occurred: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Health Professional'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('receiverID', isEqualTo: widget.healthProfessionalID)  // Query by receiverID
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                var messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var senderId = message['senderID'];
                    var messageText = message['message'];
                    var timestamp = message['timestamp'] as Timestamp;
                    var timeSent = timestamp.toDate().toLocal().toString();

                    return ListTile(
                      title: Text(messageText),
                      subtitle: Text('Sent by: $senderId at $timeSent'),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,  // Send message on pressed
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
