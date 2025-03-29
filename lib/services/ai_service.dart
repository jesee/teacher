import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  // 注意：实际使用时需要替换为真实的API密钥
  static const String _apiKey = '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';
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

  Future<String> getAIResponse(String prompt, List<Map<String, dynamic>> history) async {
    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt}
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

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'HTTP-Referer': 'https://teacher-app.com', // 替换为你的应用域名
          'X-Title': 'Teacher App',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        print('Error: ${response.statusCode}');
        print('Response: ${response.body}');
        return '抱歉，我无法处理您的请求。请稍后再试。';
      }
    } catch (e) {
      print('Exception: $e');
      return '抱歉，发生了错误。请检查您的网络连接并稍后再试。';
    }
  }
}