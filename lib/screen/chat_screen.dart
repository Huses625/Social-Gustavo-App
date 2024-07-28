import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverId;

  ChatScreen({required this.chatId, required this.receiverId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _receiverName;
  String? _receiverAvatar;

  @override
  void initState() {
    super.initState();
    _loadReceiverDetails();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadReceiverDetails() async {
    try {
      DocumentSnapshot receiverDoc =
          await _firestore.collection('users').doc(widget.receiverId).get();
      Map<String, dynamic>? data = receiverDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        setState(() {
          _receiverName =
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}';
          _receiverAvatar = data['profileImageUrl'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading receiver details: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    User? user = _auth.currentUser;
    if (user != null) {
      String content = _messageController.text.trim();

      try {
        // Fetch the user's name from Firestore
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        String senderName =
            '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}';

        Message message = Message(
          senderId: user.uid,
          senderName: senderName,
          receiverId: widget.receiverId,
          content: content,
          timestamp: DateTime.now(),
        );

        await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add(message.toMap());

        await _firestore.collection('chats').doc(widget.chatId).update({
          'lastMessage': content,
          'timestamp': DateTime.now(),
        });

        _messageController.clear();
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  Stream<List<Message>> _getMessages() {
    return _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: _receiverAvatar != null &&
                      _receiverAvatar!.isNotEmpty
                  ? NetworkImage(_receiverAvatar!)
                  : AssetImage('assets/default_avatar.png') as ImageProvider,
            ),
            SizedBox(width: 10),
            Text(_receiverName ?? 'Loading...'),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _getMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                List<Message> messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    Message message = messages[index];
                    bool isSender = message.senderId == _auth.currentUser?.uid;

                    return Row(
                      mainAxisAlignment: isSender
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Container(
                          margin: isSender
                              ? EdgeInsets.only(
                                  left: 50.0, bottom: 5.0, right: 8.0)
                              : EdgeInsets.only(
                                  right: 50.0, bottom: 5.0, left: 8.0),
                          padding: EdgeInsets.all(10.0),
                          width: MediaQuery.of(context).size.width * 0.6,
                          decoration: BoxDecoration(
                            color: isSender ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                              bottomLeft:
                                  isSender ? Radius.circular(10) : Radius.zero,
                              bottomRight:
                                  isSender ? Radius.zero : Radius.circular(10),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isSender
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isSender ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                DateFormat('hh:mm a').format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isSender ? Colors.white70 : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String senderId;
  final String senderName;
  final String receiverId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderId: map['senderId'],
      senderName: map['senderName'],
      receiverId: map['receiverId'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
