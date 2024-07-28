import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gustavo_firebase/screen/login_screen.dart';
import 'package:gustavo_firebase/screen/main_screen.dart';
import 'package:gustavo_firebase/screen/newsfeed_screen.dart';
import 'package:gustavo_firebase/screen/user_profile_screen.dart';

class CustomNavigationDrawer extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(),
                child: Text(
                  'GUSTAVO APP v1',
                  style: TextStyle(
                    color: Color.fromARGB(255, 8, 8, 8),
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.home),
                title: Text('Home'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.radio_button_on_rounded),
                title: Text('FM Streaming'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewProfileScreen(userId: _auth.currentUser!.uid),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.tv_rounded),
                title: Text('Videos'),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewProfileScreen(userId: _auth.currentUser!.uid),
                    ),
                  );
                },
              ),
            ],
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Logout'),
            onTap: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
