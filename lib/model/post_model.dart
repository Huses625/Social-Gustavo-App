import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final String content;
  final String? imageUrl;
  final Timestamp timestamp;
  final List<String> likes;
  final int comments;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    required this.likes,
    required this.comments,
  });

  factory Post.fromMap(Map<String, dynamic> data, String documentId) {
    return Post(
      id: documentId,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userAvatar: data['userAvatar'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likes: List<String>.from(data['likes'] ?? []),
      comments: data['comments'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
      'likes': likes,
      'comments': comments,
    };
  }
}
