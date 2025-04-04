class Conversation {
  final int? id;
  final String title;
  final DateTime createdAt;
  final List<Message> messages;

  Conversation({
    this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map, List<Message> messages) {
    return Conversation(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      messages: messages,
    );
  }
}

class Message {
  final int? id;
  final int? conversationId;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  Message({
    this.id,
    this.conversationId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'content': content,
      'isUser': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      conversationId: map['conversationId'],
      content: map['content'],
      isUser: map['isUser'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Message copyWithLoading() {
    return Message(
      id: id,
      conversationId: conversationId,
      content: content,
      isUser: isUser,
      timestamp: timestamp,
      isLoading: true,
    );
  }

  Message copyWithContent(String newContent) {
    return Message(
      id: id,
      conversationId: conversationId,
      content: newContent,
      isUser: isUser,
      timestamp: timestamp,
      isLoading: false,
    );
  }
}