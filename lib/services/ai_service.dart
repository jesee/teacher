import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // 注意：实际使用时需要替换为真实的API密钥
  static Future<String> get _apiKey async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('apiKey');
    if (storedKey == null || storedKey.isEmpty) {
      throw Exception('请先配置API密钥');
    }
    return storedKey;
  }
  static const String _modelName = 'deepseek/deepseek-chat-v3-0324:free';

  static const String _systemPrompt = '''
你是一个专业的教育助手，你的主要职责是通过语音对话的方式帮助用户高效学习。请遵循以下步骤：
1. 首先理解用户想要学习的内容
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

  Future<String> getAIResponse(
    String prompt,
    List<Map<String, dynamic>> history,
  ) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final messages = [
          {'role': 'system', 'content': _systemPrompt},
        ];

        // 添加历史消息
        for (var message in history) {
          messages.add({
            'role': message['isUser'] ? 'user' : 'assistant',
            'content': message['content'],
          });
        }

        // 添加当前用户消息
        messages.add({'role': 'user', 'content': prompt});

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _apiKey}',
            'HTTP-Referer': 'https://teacher-app.com',
            'X-Title': 'Teacher App',
            'User-Agent': 'TeacherApp/1.0',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'model': _modelName,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 2000,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content'];
          if (content != null) {
            return content;
          }
          throw Exception('无效的API响应格式');
        } else {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          print('Error: ${response.statusCode}');
          print('Response: ${errorBody}');

          if (response.statusCode == 401) {
            return '抱歉，API认证失败，请检查API密钥是否有效。';
          } else if (response.statusCode == 429 || response.statusCode >= 500) {
            if (retryCount < _maxRetries - 1) {
              retryCount++;
              await Future.delayed(_retryDelay * retryCount);
              continue;
            }
            return response.statusCode == 429
                ? '抱歉，请求过于频繁，请稍后再试。'
                : '抱歉，服务器暂时不可用，请稍后再试。';
          }
          return '抱歉，我无法处理您的请求。请稍后再试。';
        }
      } catch (e) {
        print('Exception: $e');
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('SocketException') || 
            e.toString().contains('TimeoutException')) {
          if (retryCount < _maxRetries - 1) {
            retryCount++;
            print('Retrying... Attempt $retryCount of ${_maxRetries - 1}');
            await Future.delayed(_retryDelay * retryCount);
            continue;
          }
          return '抱歉，网络连接出现问题。请检查您的网络连接并稍后再试。';
        }
        
        if (retryCount < _maxRetries - 1) {
          retryCount++;
          print('Retrying... Attempt $retryCount of ${_maxRetries - 1}');
          await Future.delayed(_retryDelay * retryCount);
          continue;
        }
        return '抱歉，请求处理过程中出现错误，请稍后再试。错误信息：${e.toString()}';
      }
    }
    return '抱歉，多次尝试后服务仍然不可用，请稍后再试。';

  }
}
