import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gustavo_firebase/model/post_model.dart';
import 'package:gustavo_firebase/screen/notification_screen.dart';
import 'package:gustavo_firebase/screen/user_list_screen.dart';
import 'package:gustavo_firebase/screen/user_profile_screen.dart';
import '../service/custom_cache_manager.dart'; // Import your custom cache manager
import '../service/shimmer_loading_widget.dart'; // Import the shimmer loading widget
import 'add_post_screen.dart';
import 'edit_post_screen.dart';
import 'comment_screen.dart';
import '../service/full_screen_image_viewer.dart'; // Import the full screen image viewer

import 'package:badges/badges.dart'
    as badges; // Prefixed import for badges package

class NewsfeedScreen extends StatefulWidget {
  @override
  _NewsfeedScreenState createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _profileImageUrl;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _profileImageUrl = userDoc['profileImageUrl'] ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _profileImageUrl = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User profile does not exist.'),
            ),
          );
        }
      }
    }
  }

  Stream<int> _getUnreadMessageCountStream() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .snapshots()
          .map((snapshot) {
        int unreadCount = 0;
        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          unreadCount += (data['unread_${user.uid}'] ?? 0) as int;
        }
        return unreadCount;
      });
    } else {
      return Stream.value(0);
    }
  }

  Stream<List<Post>> _getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Post> posts = [];
      for (var doc in snapshot.docs) {
        var post = Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        // Fetch user profile picture URL and other user details
        var userDoc =
            await _firestore.collection('users').doc(post.userId).get();
        if (userDoc.exists) {
          post = Post(
            id: post.id,
            userId: post.userId,
            username: '${userDoc['firstName']} ${userDoc['lastName']}',
            userAvatar: userDoc['profileImageUrl'] ?? '',
            content: post.content,
            imageUrl: post.imageUrl,
            timestamp: post.timestamp,
            likes: post.likes,
            comments: post.comments,
          );
        } else {
          post = Post(
            id: post.id,
            userId: post.userId,
            username: 'Unknown User',
            userAvatar: '',
            content: post.content,
            imageUrl: post.imageUrl,
            timestamp: post.timestamp,
            likes: post.likes,
            comments: post.comments,
          );
        }
        posts.add(post);
      }
      return posts;
    });
  }

  Future<void> _refreshPosts() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _likePost(String postId, bool isLiked) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentReference postRef = _firestore.collection('posts').doc(postId);
        if (isLiked) {
          await postRef.update({
            'likes': FieldValue.arrayRemove([user.uid])
          });
        } else {
          await postRef.update({
            'likes': FieldValue.arrayUnion([user.uid])
          });
        }
      } catch (e) {
        print('Error liking post: $e');
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
      print('Post deleted successfully');
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  void _confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Post'),
          content: Text(
              'This cannot be undone. Are you sure you want to delete this post?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost(postId);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToProfile(String userId) {
    if (userId == _auth.currentUser?.uid) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ViewProfileScreen(userId: _auth.currentUser!.uid),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewProfileScreen(userId: userId),
        ),
      );
    }
  }

  Future<void> _sendFollowRequest(String userId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      QuerySnapshot requestSnapshot = await _firestore
          .collection('followRequests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestSnapshot.docs.isEmpty) {
        await _firestore.collection('followRequests').add({
          'from': currentUser.uid,
          'to': userId,
          'status': 'pending',
        });

        // Optionally, you can send a notification to the viewed user
        await _firestore.collection('notifications').add({
          'recipientId': userId,
          'title': 'Follow Request',
          'body': '${currentUser.displayName} wants to follow you.',
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {});
      }
    }
  }

  Future<bool> _isFollowing(String userId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot followDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(userId)
          .get();

      return followDoc.exists;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('GUSTAVO APP v1'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationScreen()),
              );
            },
          ),
          StreamBuilder<int>(
            stream: _getUnreadMessageCountStream(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.data ?? 0;
              return badges.Badge(
                badgeContent: Text(
                  unreadCount.toString(),
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                showBadge: unreadCount > 0,
                badgeStyle: badges.BadgeStyle(badgeColor: Colors.red),
                position: badges.BadgePosition.topEnd(top: 0, end: 3),
                child: IconButton(
                  icon: Icon(
                    Icons.message_rounded,
                    color: unreadCount > 0 ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserListScreen()),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: StreamBuilder<List<Post>>(
          stream: _getPosts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No posts yet.'));
            }

            List<Post> posts = snapshot.data!;
            User? currentUser = _auth.currentUser;

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                Post post = posts[index];
                bool isOwner = currentUser?.uid == post.userId;
                bool isLiked = post.likes.contains(currentUser?.uid);

                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: GestureDetector(
                          onTap: () => _navigateToProfile(post.userId),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: (post.userAvatar != null &&
                                    post.userAvatar!.isNotEmpty)
                                ? NetworkImage(post.userAvatar!)
                                : AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                          ),
                        ),
                        title: GestureDetector(
                          onTap: () {
                            _navigateToProfile(post.userId);
                          },
                          child: Text(post.username),
                        ),
                        subtitle: Text(
                          post.timestamp
                              .toDate()
                              .toLocal()
                              .toString()
                              .split(' ')[0],
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: FutureBuilder<bool>(
                          future: _isFollowing(post.userId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            bool isFollowing = snapshot.data ?? false;
                            if (isOwner) {
                              return PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'Edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EditPostScreen(post: post),
                                      ),
                                    );
                                  } else if (value == 'Delete') {
                                    _confirmDeletePost(post.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return {'Edit', 'Delete'}
                                      .map((String choice) {
                                    return PopupMenuItem<String>(
                                      value: choice,
                                      child: Text(choice),
                                    );
                                  }).toList();
                                },
                              );
                            } else if (!isFollowing) {
                              return IconButton(
                                icon: Icon(Icons.person_add),
                                onPressed: () {
                                  _sendFollowRequest(post.userId);
                                },
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                      if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageUrls: [post.imageUrl!],
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 340,
                              child: CachedNetworkImage(
                                imageUrl: post.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    ShimmerLoadingWidget(
                                        width: double.infinity,
                                        height: 340), // Shimmer loading effect
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error),
                                cacheManager:
                                    CustomCacheManager(), // Use custom cache manager
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(post.content),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isLiked ? Colors.red : null,
                              ),
                              onPressed: () {
                                _likePost(post.id, isLiked);
                              },
                            ),
                            Text('${post.likes.length} likes'),
                            SizedBox(width: 16.0),
                            IconButton(
                              icon: Icon(Icons.comment),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CommentScreen(postId: post.id),
                                  ),
                                );
                              },
                            ),
                            Text('${post.comments} comments'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
