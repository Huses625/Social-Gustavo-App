import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _acceptFollowRequest(String requestId, String fromUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentReference currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      DocumentReference fromUserRef =
          _firestore.collection('users').doc(fromUserId);

      await currentUserRef.collection('followers').doc(fromUserId).set({});
      await fromUserRef.collection('following').doc(currentUser.uid).set({});

      await _firestore.collection('followRequests').doc(requestId).update({
        'status': 'accepted',
      });

      DocumentSnapshot fromUserDoc = await fromUserRef.get();
      Map<String, dynamic>? fromUserData =
          fromUserDoc.data() as Map<String, dynamic>?;

      String fromFirstName = fromUserData?['firstName'] ?? 'Unknown';
      String fromLastName = fromUserData?['lastName'] ?? 'User';

      DocumentSnapshot currentUserDoc = await currentUserRef.get();
      Map<String, dynamic>? currentUserData =
          currentUserDoc.data() as Map<String, dynamic>?;

      String currentFirstName = currentUserData?['firstName'] ?? 'Unknown';
      String currentLastName = currentUserData?['lastName'] ?? 'User';

      await _firestore.collection('posts').add({
        'content':
            '$currentFirstName $currentLastName and $fromFirstName $fromLastName are now connected.',
        'timestamp': Timestamp.now(),
        'userId': currentUser.uid,
        'username':
            currentUserData?['firstName'] + ' ' + currentUserData?['lastName'],
        'userAvatar': currentUserData?['profileImageUrl'] ?? '',
        'likes': [],
        'comments': 0,
      });
    }
  }

  Future<void> _declineFollowRequest(String requestId) async {
    await _firestore.collection('followRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
      ),
      body: currentUser == null
          ? Center(child: Text('Please log in to see notifications.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('followRequests')
                  .where('to', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No notifications.'));
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('users')
                          .doc(data['from'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Loading...'),
                          );
                        }
                        if (userSnapshot.hasError || !userSnapshot.hasData) {
                          return ListTile(
                            leading: Icon(Icons.error),
                            title: Text('Error loading user data.'),
                          );
                        }
                        var userData =
                            userSnapshot.data?.data() as Map<String, dynamic>?;
                        return ListTile(
                          leading: userData?['profileImageUrl'] != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      userData!['profileImageUrl']),
                                )
                              : CircleAvatar(child: Icon(Icons.person)),
                          title: Text(
                              '${userData?['firstName']} ${userData?['lastName']} wants to follow you.'),
                          subtitle: Text('Status: ${data['status']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () {
                                  _acceptFollowRequest(doc.id, data['from']);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.clear, color: Colors.red),
                                onPressed: () {
                                  _declineFollowRequest(doc.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}
