import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import '../models/conversation.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';
import '../providers/speech_settings_provider.dart';

class ConversationProvider with ChangeNotifier {
  final List<Message> _messages = [];
  List<Message> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final AIService _aiService = AIService();
  final DatabaseService _databaseService = DatabaseService();
  Conversation? _currentConversation;
  
  // 添加一个BuildContext引用，用于访问Provider
  BuildContext? _context;
  
  // 设置context的方法
  void setContext(BuildContext context) {
    _context = context;
  }

  Function? _onMessageAdded; // 消息添加回调
  
  // 设置消息添加回调
  void setOnMessageAdded(Function callback) {
    _onMessageAdded = callback;
  }

  Future<void> addMessage(Message message) async {
    _messages.add(message);
    notifyListeners();
    
    // 触发消息添加回调
    _onMessageAdded?.call();
    
    await _saveConversation();
    
    // 添加一个AI回复的加载中状态消息
    final loadingMessage = Message(
      content: "", // 使用空内容，UI层会显示加载动画 
      isUser: false, 
      timestamp: DateTime.now(),
      isLoading: true
    );
    _messages.add(loadingMessage);
    _isLoading = true;
    notifyListeners();
    
    // 再次触发消息添加回调
    _onMessageAdded?.call();

    try {
      final history = _messages
        .where((m) => !m.isLoading) // 排除加载中的消息
        .map((m) => {
          'isUser': m.isUser,
          'content': m.content,
        }).toList();

      final response = message.imageBase64 != null
        ? await _aiService.getAIResponseWithImage(message, history)
        : await _aiService.getAIResponse(message.content, history);
      
      // 移除加载中的消息
      _messages.removeWhere((m) => m.isLoading);
      
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
      }
    } catch (e) {
      print('Error in addMessage: $e');
      // 移除加载中的消息
      _messages.removeWhere((m) => m.isLoading);
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
    
    // 触发消息添加回调
    _onMessageAdded?.call();
    
    await _saveConversation();
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

  // 重命名对话
  Future<void> renameConversation(int id, String newTitle) async {
    await _databaseService.updateConversationTitle(id, newTitle);
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