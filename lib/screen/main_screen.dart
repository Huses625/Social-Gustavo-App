import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gustavo_firebase/component/bottom_navigation.dart';
import 'package:gustavo_firebase/screen/chat_screen.dart';
import 'package:gustavo_firebase/screen/add_post_screen.dart';
import 'package:gustavo_firebase/screen/edit_profile_screen.dart';
import 'package:gustavo_firebase/screen/search_screen.dart';
import 'package:gustavo_firebase/screen/short_video_screen.dart';
import 'package:gustavo_firebase/screen/newsfeed_screen.dart';
import 'package:gustavo_firebase/screen/user_profile_screen.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _profileImageUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Add a variable to hold the Firestore subscription
  StreamSubscription<QuerySnapshot>? _messageSubscription;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      NewsfeedScreen(),
      SearchScreen(),
      AddPostScreen(),
      ShortVideoScreen(),
      ViewProfileScreen(userId: _currentUser?.uid ?? ''),
    ];
    _loadUserProfile();
    _initializeLocalNotifications();
    _listenForMessages();
  }

  @override
  void dispose() {
    // Cancel the Firestore subscription if it exists
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _profileImageUrl = userDoc['profileImageUrl'];
        });
      }
    }
  }

  void _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
      if (response.payload != null) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: response.payload!.split(':')[0],
            receiverId: response.payload!.split(':')[1],
          ),
        ));
      }
    });
  }

  void _listenForMessages() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _messageSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return; // Check if the widget is still mounted
        for (var doc in snapshot.docs) {
          FirebaseFirestore.instance
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .snapshots()
              .listen((messageSnapshot) {
            if (!mounted) return; // Check if the widget is still mounted
            if (messageSnapshot.docs.isNotEmpty) {
              var message = messageSnapshot.docs.first.data();
              if (message['senderId'] != user.uid) {
                _showNotification(
                  doc.id,
                  message['senderId'],
                  message['senderName'],
                  message['content'],
                );
              }
            }
          });
        }
      });
    }
  }

  Future<void> _showNotification(
      String chatId, String senderId, String senderName, String content) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      senderName,
      content.length > 20 ? '${content.substring(0, 20)}...' : content,
      platformChannelSpecifics,
      payload: '$chatId:$senderId',
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Add navigation logic here if necessary
    // Navigator.pushReplacement(...)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
