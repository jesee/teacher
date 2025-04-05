import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../services/sensitive_word_service.dart';
import '../models/conversation.dart';

class AIService {
  final DatabaseService _databaseService = DatabaseService();
  final SensitiveWordService _sensitiveWordService = SensitiveWordService();

  Future<Map<String, String>> _getConfig() async {
    final config = await _databaseService.getEnabledAIModelConfig();
    
    if (config == null) {
      throw Exception('请先在设置中配置AI模型');
    }
    
    if (config['apiKey'] == null || config['apiKey'].toString().isEmpty) {
      throw Exception('API密钥未配置，请在设置中完成模型配置');
    }
    
    return {
      'apiUrl': config['apiUrl'],
      'apiKey': config['apiKey'],
      'modelName': config['modelName'],
    };
  }

  static const String _systemPrompt = '''
你是一个专业的教育助手，你的主要职责是通过语音对话的方式帮助用户高效学习。请遵循以下步骤：
1. 首先理解用户想要学习的内容和目的
2. 提炼出核心知识点
3. 告知用户最佳的学习顺序
4. 循序渐进地引导用户学习
5. 定期询问用户的理解程度
6. 如果用户有不理解的地方，耐心解答直到完全掌握

在回答时，请：
- 使用清晰、易懂的语言
- 适时提供具体的例子
- 保持对话的连贯性
- 积极鼓励用户提问
- 根据用户的反馈调整讲解方式
''';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  Future<String> getAIResponse(String message, List<Map<String, dynamic>> history) async {
    final config = await _getConfig();
    
    // 检查敏感词
    final containsSensitiveWord = await _sensitiveWordService.containsSensitiveWord(message);
    if (containsSensitiveWord) {
      return '抱歉，您的消息包含敏感词，请修改后重试。';
    }
    
    final url = Uri.parse(config['apiUrl']!);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config['apiKey']}',
    };
    
    final body = {
      'model': config['modelName'],
      'messages': [
        {
          'role': 'system',
          'content': _systemPrompt,
        },
        ...history.map((msg) => {
          'role': msg['isUser'] ? 'user' : 'assistant',
          'content': msg['content'],
        }).toList(),
        {
          'role': 'user',
          'content': message,
        },
      ],
      'temperature': 0.7,
      'max_tokens': 0,
    };
    
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          return jsonResponse['choices'][0]['message']['content'];
        } else if (response.statusCode == 401) {
          return '抱歉，API认证失败，请检查API密钥是否正确。';
        } else if (response.statusCode == 429) {
          return '抱歉，请求过于频繁，请稍后再试。';
        } else {
          print('API request failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
          retryCount++;
          if (retryCount < _maxRetries) {
            await Future.delayed(_retryDelay * retryCount);
            continue;
          }
          return '抱歉，服务暂时不可用，请稍后再试。';
        }
      } catch (e) {
        print('Error in getAIResponse: $e');
        retryCount++;
        if (retryCount < _maxRetries) {
          await Future.delayed(_retryDelay * retryCount);
          continue;
        }
        return '抱歉，网络连接不稳定，请检查网络后重试。';
      }
    }
    
    return '抱歉，服务暂时不可用，请稍后再试。';
  }

  Future<String> getAIResponseWithImage(Message message, List<Map<String, dynamic>> history) async {
    final config = await _getConfig();
    
    // 检查敏感词
    final containsSensitiveWord = await _sensitiveWordService.containsSensitiveWord(message.content);
    if (containsSensitiveWord) {
      return '抱歉，您的消息包含敏感词，请修改后重试。';
    }
    
    final url = Uri.parse(config['apiUrl']!);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config['apiKey']}',
    };
    
    final body = {
      'model': config['modelName'],
      'messages': [
        {
          'role': 'system',
          'content': _systemPrompt,
        },
        ...history.map((msg) => {
          'role': msg['isUser'] ? 'user' : 'assistant',
          'content': msg['content'],
        }).toList(),
        {
          'role': 'user',
          'content': message.toApiFormat(),
        },
      ],
      'temperature': 0.7,
      'max_tokens': 0,
    };
    
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
        print('request url: ${url}');
        print('request header: ${jsonEncode(headers)}');
        print('request body: ${jsonEncode(body)}');
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));//jsonDecode(utf8.decode(response.bodyBytes));
          return jsonResponse['choices'][0]['message']['content'];
        } else if (response.statusCode == 401) {
          return '抱歉，API认证失败，请检查API密钥是否正确。';
        } else if (response.statusCode == 429) {
          return '抱歉，请求过于频繁，请稍后再试。';
        } else {
          print('API request failed with status: ${response.statusCode}');
          print('Response body: ${response.body}');
          retryCount++;
          if (retryCount < _maxRetries) {
            await Future.delayed(_retryDelay * retryCount);
            continue;
          }
          return '抱歉，服务暂时不可用，请稍后再试。';
        }
      } catch (e) {
        print('Error in getAIResponseWithImage: $e');
        retryCount++;
        if (retryCount < _maxRetries) {
          await Future.delayed(_retryDelay * retryCount);
          continue;
        }
        return '抱歉，网络连接不稳定，请检查网络后重试。';
      }
    }
    
    return '抱歉，服务暂时不可用，请稍后再试。';
  }
}
