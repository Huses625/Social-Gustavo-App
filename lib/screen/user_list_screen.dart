import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class UserListScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _getOrCreateChat(String userId1, String userId2) async {
    String chatId = '';

    QuerySnapshot existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId1)
        .get();

    bool chatExists = false;

    for (var doc in existingChats.docs) {
      List participants = doc['participants'];
      if (participants.contains(userId2)) {
        chatId = doc.id;
        chatExists = true;
        break;
      }
    }

    if (!chatExists) {
      DocumentReference newChat = await _firestore.collection('chats').add({
        'participants': [userId1, userId2],
        'lastMessage': '',
        'timestamp': DateTime.now(),
      });
      chatId = newChat.id;
    }

    return chatId;
  }

  String _truncateMessage(String message, {int maxLength = 20}) {
    if (message.length <= maxLength) {
      return message;
    } else {
      return message.substring(0, maxLength) + '...';
    }
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No conversations found.'));
          }

          List<DocumentSnapshot> docs = snapshot.data!.docs;
          List<Map<String, dynamic>> userConversations = [];

          for (var doc in docs) {
            List participants = doc['participants'];
            String otherUserId = participants
                .firstWhere((participant) => participant != currentUser?.uid);
            String lastMessage = doc['lastMessage'] ?? '';
            Timestamp timestamp = doc['timestamp'];

            userConversations.add({
              'userId': otherUserId,
              'lastMessage': lastMessage,
              'chatId': doc.id,
              'timestamp': timestamp,
            });
          }

          if (userConversations.isEmpty) {
            return Center(child: Text('No conversations found.'));
          }

          userConversations.sort((a, b) {
            return (b['timestamp'] as Timestamp).compareTo(a['timestamp']);
          });

          return ListView.builder(
            itemCount: userConversations.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> conversation = userConversations[index];
              String userId = conversation['userId'];
              String lastMessage = conversation['lastMessage'];
              String chatId = conversation['chatId'];
              Timestamp timestamp = conversation['timestamp'];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(userId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  Map<String, dynamic>? data =
                      snapshot.data?.data() as Map<String, dynamic>?;

                  if (data == null) {
                    return Container();
                  }

                  String avatarUrl = data['profileImageUrl'] ?? '';
                  String firstName = data['firstName'] ?? '';
                  String lastName = data['lastName'] ?? '';
                  DateTime dateTime = timestamp.toDate();
                  String formattedTime = DateFormat('hh:mm a').format(dateTime);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                    ),
                    title: Text('$firstName $lastName'),
                    subtitle: Text(_truncateMessage(lastMessage)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formattedTime,
                          style: TextStyle(fontSize: 12),
                        ),
                        // Add unread message indicator if needed
                      ],
                    ),
                    onTap: () async {
                      String chatId =
                          await _getOrCreateChat(currentUser!.uid, userId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatId,
                            receiverId: userId,
                          ),
                        ),
                      );
                    },
                    onLongPress: () async {
                      // Add delete chat functionality here
                      await _firestore.collection('chats').doc(chatId).delete();
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
