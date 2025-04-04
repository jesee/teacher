import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import '../services/sensitive_word_service.dart';

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

  Future<String> getAIResponse(
    String prompt,
    List<Map<String, dynamic>> history,
  ) async {
    // 初始化敏感词服务
    await _sensitiveWordService.initialize();
    
    // 检查用户输入是否包含敏感词
    if (_sensitiveWordService.containsSensitiveWords(prompt)) {
      return '抱歉，您的问题包含不当内容，请修改后重试。';
    }

    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final config = await _getConfig();
        
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
        
        // 添加当前用户的提问
        messages.add({
          'role': 'user',
          'content': prompt,
        });
        
        final response = await http.post(
          Uri.parse(config['apiUrl']!),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${config['apiKey']}',
          },
          body: jsonEncode({
            'model': config['modelName'],
            'messages': messages,
            'temperature': 0.7,
          }),
        );
        
        if (response.statusCode == 200) {
          // 使用 utf8.decode 解决中文乱码问题
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          final content = jsonResponse['choices'][0]['message']['content'];
          
          // 过滤AI回复中的敏感词
          final filteredContent = _sensitiveWordService.filterSensitiveWords(content);
          return filteredContent;
        } else {
          throw Exception('API请求失败: ${response.statusCode} ${utf8.decode(response.bodyBytes)}');
        }
      } catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          return '抱歉，我无法回答你的问题。错误: ${e.toString()}';
        }
        await Future.delayed(_retryDelay);
      }
    }
    
    return '抱歉，服务器暂时无法响应，请稍后再试。';
  }
}
