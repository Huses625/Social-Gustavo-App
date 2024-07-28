import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gustavo_firebase/model/post_model.dart';
import 'package:gustavo_firebase/screen/main_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _contentController = TextEditingController();
  bool showSpinner = false;
  File? _selectedImage;
  String? _profileImageUrl;

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
      if (mounted) {
        setState(() {
          _profileImageUrl = userDoc['profileImageUrl'];
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef =
          _storage.ref().child('post_images').child(fileName);

      // Show progress SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Uploading image...'),
            ],
          ),
          duration: Duration(minutes: 1),
        ),
      );

      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot taskSnapshot = await uploadTask;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have successfully shared your post!')),
      );

      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _addPost() async {
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

          String? imageUrl;
          if (_selectedImage != null) {
            imageUrl = await _uploadImage(_selectedImage!);
          }

          Post post = Post(
            id: '',
            userId: user.uid,
            username: username,
            content: _contentController.text,
            timestamp: Timestamp.now(),
            likes: [],
            comments: 0,
            imageUrl: imageUrl,
          );

          await _firestore.collection('posts').add(post.toMap());

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        } else {
          setState(() {
            showSpinner = false;
          });
          print('User data is null');
        }
      } else {
        setState(() {
          showSpinner = false;
        });
        print('User is null');
      }
    } catch (e) {
      setState(() {
        showSpinner = false;
      });
      print('Error adding post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Post'),
        actions: [
          if (_profileImageUrl != null)
            CircleAvatar(
              backgroundImage: NetworkImage(_profileImageUrl!),
            ),
          SizedBox(width: 10), // Add some padding
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write something...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            _selectedImage != null
                ? Image.file(_selectedImage!)
                : Text('No image selected'),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  child: Text('Pick from Gallery'),
                ),
                ElevatedButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  child: Text('Capture Image'),
                ),
              ],
            ),
            SizedBox(height: 16.0),
            showSpinner
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _addPost,
                    child: Text('Post'),
                  ),
          ],
        ),
      ),
    );
  }
}
