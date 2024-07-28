import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowingScreen extends StatefulWidget {
  final String userId;

  FollowingScreen({required this.userId});

  @override
  _FollowingScreenState createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Following'),
      ),
      body: _currentUser == null
          ? Center(child: Text('Please log in to see following list.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection('following')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Not following anyone.'));
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    var followingId = doc.id;
                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          _firestore.collection('users').doc(followingId).get(),
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
                              '${userData?['firstName']} ${userData?['lastName']}'),
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
