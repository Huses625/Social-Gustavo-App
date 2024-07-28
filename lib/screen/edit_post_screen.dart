import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gustavo_firebase/model/post_model.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  EditPostScreen({required this.post});

  @override
  _EditPostScreenState createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _firestore = FirebaseFirestore.instance;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
  }

  Future<void> _editPost() async {
    try {
      await _firestore.collection('posts').doc(widget.post.id).update({
        'content': _contentController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      Navigator.pop(context);
      print('Post edited successfully');
    } catch (e) {
      print('Error editing post: $e');
    }
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
        title: Text('Edit Post'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Edit your post...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _editPost,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
