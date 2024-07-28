import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  User? _user;
  File? _imageFile;
  String? _profileImageUrl;
  String? _coverImageUrl;
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();
  TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (mounted) {
        setState(() {
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          _profileImageUrl = data?['profileImageUrl'] ?? '';
          _coverImageUrl = data?['coverImageUrl'] ?? '';
          _firstNameController.text = data?['firstName'] ?? '';
          _lastNameController.text = data?['lastName'] ?? '';
          _bioController.text = data?['bio'] ?? '';
        });
      }
    }
  }

  Future<void> _uploadImage({required bool isCover}) async {
    try {
      String filePath = isCover
          ? 'cover_images/${_user!.uid}.png'
          : 'profile_images/${_user!.uid}.png';
      await _storage.ref(filePath).putFile(_imageFile!);
      String downloadUrl = await _storage.ref(filePath).getDownloadURL();
      await _updateUserProfilePicture(downloadUrl, isCover: isCover);
      if (mounted) {
        setState(() {
          if (isCover) {
            _coverImageUrl = downloadUrl;
          } else {
            _profileImageUrl = downloadUrl;
          }
        });
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> _pickImage({required bool isCover}) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile != null ? File(pickedFile.path) : null;
    });
    if (_imageFile != null) {
      _uploadImage(isCover: isCover);
    }
  }

  Future<void> _updateUserProfilePicture(String downloadUrl,
      {required bool isCover}) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        isCover ? 'coverImageUrl' : 'profileImageUrl': downloadUrl,
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_user != null) {
      await _firestore.collection('users').doc(_user!.uid).update({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'bio': _bioController.text,
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _pickImage(isCover: true),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image:
                          _coverImageUrl != null && _coverImageUrl!.isNotEmpty
                              ? NetworkImage(_coverImageUrl!) as ImageProvider
                              : AssetImage('assets/default_cover.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: _coverImageUrl == null || _coverImageUrl!.isEmpty
                      ? Center(child: Icon(Icons.camera_alt, size: 80))
                      : null,
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () => _pickImage(isCover: false),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? NetworkImage(_profileImageUrl!)
                          : AssetImage('assets/default_avatar.png'),
                  child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? Icon(Icons.camera_alt, size: 50)
                      : null,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _bioController,
                decoration: InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProfile,
                child: Text('Update Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
