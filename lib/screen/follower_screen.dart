import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;

  FollowersScreen({required this.userId});

  @override
  _FollowersScreenState createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
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
        title: Text('Followers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No followers.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var followerId = doc.id;
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(followerId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
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
                            backgroundImage:
                                NetworkImage(userData!['profileImageUrl']),
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

// Example ProfileScreen
class ProfileScreen extends StatelessWidget {
  final String profileUserId;

  ProfileScreen({required this.profileUserId});

  void _navigateToFollowersScreen(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Assuming you have some way of determining if this is the current user or not
    final isCurrentUser =
        profileUserId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Column(
        children: [
          // Other profile details here
          ElevatedButton(
            onPressed: () {
              _navigateToFollowersScreen(context, profileUserId);
            },
            child: Text('View Followers'),
          ),
        ],
      ),
    );
  }
}
