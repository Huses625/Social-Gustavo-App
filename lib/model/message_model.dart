class Message {
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String receiverId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderId: map['senderId'],
      senderName: map['senderName'],
      senderAvatar: map['senderAvatar'],
      receiverId: map['receiverId'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
