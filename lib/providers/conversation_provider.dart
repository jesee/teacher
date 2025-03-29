import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

class ConversationProvider with ChangeNotifier {
  final List<Message> _messages = [];
  List<Message> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final AIService _aiService = AIService();
  final DatabaseService _databaseService = DatabaseService();
  Conversation? _currentConversation;

  Future<void> addMessage(Message message) async {
    _messages.add(Message(content: message.content, isUser: true, timestamp: DateTime.now()));
    notifyListeners();
    
    _isLoading = true;
    notifyListeners();

    try {
      final history = _messages.map((m) => {
        'isUser': m.isUser,
        'content': m.content,
      }).toList();

      final response = await _aiService.getAIResponse(message.content, history);
      addAIResponse(response);
    } catch (e) {
      addAIResponse('抱歉，我遇到了一些问题，请稍后再试。');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addAIResponse(String content) {
    _messages.add(Message(content: content, isUser: false, timestamp: DateTime.now()));
    notifyListeners();
    _saveConversation();
  }

  void clearMessages() {
    _messages.clear();
    _currentConversation = null;
    notifyListeners();
  }

  Future<void> loadConversation(Conversation conversation) async {
    _messages.clear();
    _messages.addAll(conversation.messages);
    _currentConversation = conversation;
    notifyListeners();
  }

  Future<void> _saveConversation() async {
    if (_messages.isEmpty) return;
    
    if (_currentConversation == null) {
      final firstMessage = _messages.first.content;
      final title = firstMessage.length > 20 ? '${firstMessage.substring(0, 20)}...' : firstMessage;
      
      _currentConversation = Conversation(
        title: title,
        createdAt: DateTime.now(),
        messages: _messages,
      );
    } else {
      _currentConversation = Conversation(
        id: _currentConversation!.id,
        title: _currentConversation!.title,
        createdAt: _currentConversation!.createdAt,
        messages: _messages,
      );
    }
    
    final id = await _databaseService.saveConversation(_currentConversation!);
    if (_currentConversation!.id == null) {
      _currentConversation = Conversation(
        id: id,
        title: _currentConversation!.title,
        createdAt: _currentConversation!.createdAt,
        messages: _messages,
      );
    }
  }

}