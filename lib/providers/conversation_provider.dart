import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';

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
    await _saveConversation();
    
    _isLoading = true;
    notifyListeners();

    try {
      final history = _messages.map((m) => {
        'isUser': m.isUser,
        'content': m.content,
      }).toList();

      final response = await _aiService.getAIResponse(message.content, history);
      if (response.contains('抱歉') || response.contains('错误')) {
        print('AI Service returned error: $response');
        // 如果是网络错误，我们给出更友好的提示
        if (response.contains('网络连接')) {
          await addAIResponse('抱歉，网络连接不稳定，请检查网络后重试。');
        } else if (response.contains('API认证失败')) {
          await addAIResponse('抱歉，服务认证失败，请联系管理员。');
        } else if (response.contains('请求过于频繁')) {
          await addAIResponse('抱歉，服务器正忙，请稍后再试。');
        } else {
          await addAIResponse(response);
        }
      } else {
        await addAIResponse(response);
        // 获取最后一条消息并播放语音
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          final speechService = SpeechService();
          await speechService.speak(_messages.last.content, messageId: _messages.last.id);
        }
      }
    } catch (e) {
      print('Error in addMessage: $e');
      await addAIResponse('抱歉，处理消息时遇到了问题，请稍后再试。');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAIResponse(String content) async {
    final message = Message(content: content, isUser: false, timestamp: DateTime.now());
    _messages.add(message);
    notifyListeners();
    await _saveConversation();
    
    // 自动播放AI回复的语音
    try {
      final speechService = SpeechService();
      await speechService.speak(content, messageId: message.id);
    } catch (e) {
      print('语音播放失败: $e');
    }
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

  Future<void> deleteConversation(int id) async {
    final db = await _databaseService.database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
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