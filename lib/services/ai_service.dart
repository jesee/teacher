import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  static Future<String> get _apiUrl async {
    final prefs = await SharedPreferences.getInstance();
    final storedUrl = prefs.getString('apiUrl');
    return storedUrl ?? 'https://openrouter.ai/api/v1/chat/completions';
  }

  static Future<String> get _apiKey async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('apiKey');
    if (storedKey == null || storedKey.isEmpty) {
      throw Exception('请先配置API密钥');
    }
    return storedKey;
  }
  
  static Future<String> get _modelName async {
    final prefs = await SharedPreferences.getInstance();
    final storedModel = prefs.getString('modelName');
    return storedModel ?? 'google/gemini-2.0-flash-thinking-exp:free';
  }

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
        messages.add({
          'role': 'user',
          'content': prompt,
        });

        final apiUrl = await _apiUrl;
        final apiKey = await _apiKey;
        final modelName = await _modelName;

        // 打印请求信息
        print('发送请求到: $apiUrl');
        print('使用模型: $modelName');
        print('请求内容: ${jsonEncode(messages)}');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': messages,
          }),
        );

        // 打印响应信息
        print('响应状态码: ${response.statusCode}');
        print('响应头: ${response.headers}');
        print('原始响应内容: ${response.body}');

        if (response.statusCode == 200) {
          // 使用 utf8 解码响应内容
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          print('解码后的响应内容: $jsonResponse');
          
          final content = jsonResponse['choices'][0]['message']['content'];
          print('最终提取的内容: $content');
          return content;
        } else {
          throw Exception('API请求失败: ${response.statusCode} ${utf8.decode(response.bodyBytes)}');
        }
      } catch (e) {
        print('发生错误: $e');
        retryCount++;
        if (retryCount >= _maxRetries) {
          throw Exception('请求失败，请检查网络连接和API配置: $e');
        }
        await Future.delayed(_retryDelay);
      }
    }
    throw Exception('请求失败，已达到最大重试次数');
  }
}
