import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PassiveBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  PassiveBottomNavigation({required this.currentIndex, required this.onTap});

  @override
  _CustomBottomNavigationBarState createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<PassiveBottomNavigation> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _profileImageUrl = userDoc['profileImageUrl'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add),
          label: 'New Post',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_camera_back),
          label: 'Videos',
        ),
        BottomNavigationBarItem(
          icon: _profileImageUrl != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(_profileImageUrl!),
                  radius: 15,
                )
              : Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
    );
  }
}
