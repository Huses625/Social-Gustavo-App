import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gustavo_firebase/model/comment_model.dart';
import 'package:gustavo_firebase/screen/user_profile_screen.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  CommentScreen({required this.postId});

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _contentController = TextEditingController();
  bool showSpinner = false;

  Stream<List<Comment>> _getComments() {
    return _firestore
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Comment> comments = [];
      for (var doc in snapshot.docs) {
        var comment =
            Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        // Fetch user profile picture URL
        var userDoc =
            await _firestore.collection('users').doc(comment.userId).get();
        comment = Comment(
          id: comment.id,
          userId: comment.userId,
          username: comment.username,
          userAvatar: userDoc['profileImageUrl'],
          content: comment.content,
          timestamp: comment.timestamp,
        );
        comments.add(comment);
      }
      return comments;
    });
  }

  Future<void> _addComment() async {
    setState(() {
      showSpinner = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        if (userData != null) {
          String username = '${userData['firstName']} ${userData['lastName']}';
          String userAvatar = userData['profileImageUrl'] ?? '';

          Comment comment = Comment(
            id: '', // Firestore will generate the ID
            userId: user.uid,
            username: username,
            userAvatar: userAvatar,
            content: _contentController.text,
            timestamp: DateTime.now(),
          );

          await _firestore
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .add(comment.toMap());
          await _firestore.collection('posts').doc(widget.postId).update({
            'comments': FieldValue.increment(1),
          });
          _contentController.clear();
        }
      }
    } catch (e) {
      print('Error adding comment: $e');
    } finally {
      setState(() {
        showSpinner = false;
      });
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ViewProfileScreen(userId: userId)),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _getComments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No comments yet.'));
                }

                List<Comment> comments = snapshot.data!;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    Comment comment = comments[index];

                    return ListTile(
                      leading: GestureDetector(
                        onTap: () => _navigateToProfile(comment.userId),
                        child: CircleAvatar(
                          backgroundImage: comment.userAvatar != null
                              ? NetworkImage(comment.userAvatar!)
                              : AssetImage('assets/default_avatar.png')
                                  as ImageProvider,
                        ),
                      ),
                      title: GestureDetector(
                        onTap: () => _navigateToProfile(comment.userId),
                        child: Text(comment.username),
                      ),
                      subtitle: Text(comment.content),
                      trailing: Text(
                        comment.timestamp.toLocal().toString().split(' ')[0],
                        style: TextStyle(fontSize: 12),
                      ),
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
                    controller: _contentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
