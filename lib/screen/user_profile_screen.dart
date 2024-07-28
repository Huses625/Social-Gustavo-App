import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gustavo_firebase/component/bottom_navigation.dart';
import 'package:gustavo_firebase/component/navigation_drawer.dart';
import 'package:gustavo_firebase/component/passive_bottom_navigation.dart';
import 'package:gustavo_firebase/screen/follower_screen.dart';
import 'package:gustavo_firebase/screen/following_screen.dart';
import 'package:gustavo_firebase/screen/main_screen.dart';
import 'package:gustavo_firebase/screen/notification_screen.dart';
import 'package:gustavo_firebase/screen/edit_profile_screen.dart';
import 'package:gustavo_firebase/screen/search_screen.dart';
import 'package:gustavo_firebase/screen/user_list_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'chat_screen.dart'; // Import your ChatScreen

import 'package:badges/badges.dart'
    as badges; // Prefixed import for badges package

class ViewProfileScreen extends StatefulWidget {
  final String userId;

  ViewProfileScreen({required this.userId});

  @override
  _ViewProfileScreenState createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _profileImageUrl;
  String? _coverImageUrl;
  Map<String, dynamic>? _userDetails;
  bool _isFollowing = false;
  bool _isRequestPending = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _totalLikes = 0;
  int _postsCount = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkIfFollowingOrRequested();
    _fetchUserStats();
  }

  Future<void> _loadUserProfile() async {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(widget.userId).get();
    if (mounted) {
      setState(() {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        _profileImageUrl = data?['profileImageUrl'] ?? '';
        _coverImageUrl = data?['coverImageUrl'] ?? '';
        _userDetails = data ?? {};
      });
    }
  }

  Future<void> _checkIfFollowingOrRequested() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid != widget.userId) {
      DocumentSnapshot followDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.userId)
          .get();

      QuerySnapshot requestSnapshot = await _firestore
          .collection('followRequests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _isFollowing = followDoc.exists;
        _isRequestPending = requestSnapshot.docs.isNotEmpty;
      });
    }
  }

  Future<void> _fetchUserStats() async {
    // Fetch followers count
    QuerySnapshot followersSnapshot = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .get();
    _followersCount = followersSnapshot.docs.length;

    // Fetch following count
    QuerySnapshot followingSnapshot = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .get();
    _followingCount = followingSnapshot.docs.length;

    // Fetch total likes count
    QuerySnapshot postsSnapshot = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .get();
    int totalLikes = 0;
    for (var doc in postsSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      totalLikes += (data['likes'] as List).length;
    }
    _totalLikes = totalLikes;
    _postsCount = postsSnapshot.docs.length;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFollow() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentReference currentUserRef =
          _firestore.collection('users').doc(currentUser.uid);
      DocumentReference viewedUserRef =
          _firestore.collection('users').doc(widget.userId);

      if (_isFollowing) {
        await currentUserRef
            .collection('following')
            .doc(widget.userId)
            .delete();
        await viewedUserRef
            .collection('followers')
            .doc(currentUser.uid)
            .delete();
      } else {
        await currentUserRef.collection('following').doc(widget.userId).set({});
        await viewedUserRef
            .collection('followers')
            .doc(currentUser.uid)
            .set({});
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });
    }
  }

  Future<void> _sendFollowRequest() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      QuerySnapshot requestSnapshot = await _firestore
          .collection('followRequests')
          .where('from', isEqualTo: currentUser.uid)
          .where('to', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requestSnapshot.docs.isEmpty) {
        await _firestore.collection('followRequests').add({
          'from': currentUser.uid,
          'to': widget.userId,
          'status': 'pending',
        });

        // Optionally, you can send a notification to the viewed user
        await _firestore.collection('notifications').add({
          'recipientId': widget.userId,
          'title': 'Follow Request',
          'body': '${currentUser.displayName} wants to follow you.',
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isRequestPending =
              true; // Update the button text to "Pending Request"
        });
      }
    }
  }

  Future<void> _startConversation() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Navigate to the chat screen with the userId of the profile being viewed
      String chatId = await _getOrCreateChat(currentUser.uid, widget.userId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatScreen(chatId: chatId, receiverId: widget.userId),
        ),
      );
    }
  }

  Future<String> _getOrCreateChat(String userId1, String userId2) async {
    String chatId = ''; // Initialize chatId

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

  Future<void> _refreshProfile() async {
    await _loadUserProfile();
    await _checkIfFollowingOrRequested();
    await _fetchUserStats();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Optionally, you can add navigation logic here
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    bool isCurrentUserProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isCurrentUserProfile
          ? AppBar(
              title: Text(
                _userDetails?['name'] ?? 'GUSTAVO APP v1',
                style: TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications, color: Colors.grey),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NotificationScreen()),
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
                            MaterialPageRoute(
                                builder: (context) => UserListScreen()),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      drawer: CustomNavigationDrawer(),
      body: _userDetails == null
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: _coverImageUrl != null &&
                                            _coverImageUrl!.isNotEmpty
                                        ? NetworkImage(_coverImageUrl!)
                                            as ImageProvider
                                        : AssetImage(
                                            'assets/default_cover.jpg'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top:
                                  135, // Adjust this value to position the avatar correctly
                              left: MediaQuery.of(context).size.width / 2 - 50,
                              child: GestureDetector(
                                onTap: () {},
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundImage: _profileImageUrl != null &&
                                            _profileImageUrl!.isNotEmpty
                                        ? NetworkImage(_profileImageUrl!)
                                        : AssetImage(
                                            'assets/default_avatar.png'),
                                    child: _profileImageUrl == null ||
                                            _profileImageUrl!.isEmpty
                                        ? Icon(Icons.camera_alt, size: 40)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: 60), // Adjust this value to create space
                        Text(
                          '${_userDetails?['firstName'] ?? ''} ${_userDetails?['lastName'] ?? ''}',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            _userDetails?['bio'] ?? '',
                            style: TextStyle(fontSize: 16, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(_postsCount.toString(), 'Posts',
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SearchScreen()),
                              );
                            }),
                            _buildStatColumn(
                              _followersCount.toString(),
                              'Followers',
                              () {
                                _navigateToFollowersScreen(
                                    context, widget.userId);
                              },
                            ),
                            _buildStatColumn(
                              _followingCount.toString(),
                              'Following',
                              () {
                                _navigateToFollowingScreen(
                                    context, widget.userId);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        if (isCurrentUserProfile)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Edit Profile',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: EdgeInsets.symmetric(horizontal: 50),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (_isFollowing) {
                                    _toggleFollow();
                                  } else {
                                    _sendFollowRequest();
                                  }
                                },
                                child: Text(_isFollowing
                                    ? 'Following'
                                    : _isRequestPending
                                        ? 'Pending Request'
                                        : 'Follow'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? const Color.fromARGB(255, 187, 187, 187)
                                      : const Color.fromARGB(
                                          255, 255, 255, 255),
                                  padding: EdgeInsets.symmetric(horizontal: 50),
                                ),
                              ),
                              if (_isFollowing)
                                ElevatedButton(
                                  onPressed: _startConversation,
                                  child: Text('Message'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 50),
                                  ),
                                ),
                            ],
                          ),
                        SizedBox(height: 20),
                        Container(
                          color: Colors.black,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {},
                                child: Column(
                                  children: [
                                    Text(
                                      'POSTS',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Column(
                                  children: [
                                    Text(
                                      'REELS',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCurrentUserProfile)
                    Positioned(
                      top: 40,
                      left: 10,
                      child: FloatingActionButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.arrow_back_ios),
                        mini: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatColumn(String number, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 7, 7, 7)),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
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
}

void _navigateToFollowersScreen(BuildContext context, String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FollowersScreen(userId: userId),
    ),
  );
}

void _navigateToFollowingScreen(BuildContext context, String userId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FollowingScreen(userId: userId),
    ),
  );
}
