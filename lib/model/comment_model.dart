class Comment {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar; // Add this field
  final String content;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar, // Add this field
    required this.content,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String documentId) {
    return Comment(
      id: documentId,
      userId: data['userId'],
      username: data['username'],
      userAvatar: data['userAvatar'], // Add this field
      content: data['content'],
      timestamp: DateTime.parse(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar, // Add this field
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
