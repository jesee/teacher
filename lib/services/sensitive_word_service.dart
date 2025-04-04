import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

class DFANode {
  Map<String, DFANode> next = {};
  bool isEnd = false;
}

class SensitiveWordService {
  static const bool ENABLE_SENSITIVE_WORD_FILTER = false; // 敏感词过滤开关，true表示开启过滤，false表示关闭过滤
  
  static final SensitiveWordService _instance = SensitiveWordService._internal();
  factory SensitiveWordService() => _instance;
  SensitiveWordService._internal();

  DFANode root = DFANode();
  bool _isInitialized = false;

  // 初始化DFA
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 加载基础词库
      final String content = await rootBundle.loadString('assets/sensitive_words/base.txt');
      final List<String> words = content
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .toList();

      // 构建DFA
      for (var word in words) {
        addWord(word.trim());
      }
      
      _isInitialized = true;
    } catch (e) {
      print('初始化敏感词库失败: $e');
      rethrow;
    }
  }

  // 添加敏感词到DFA
  void addWord(String word) {
    if (word.isEmpty) return;
    
    DFANode current = root;
    for (var char in word.characters) {
      current.next[char] ??= DFANode();
      current = current.next[char]!;
    }
    current.isEnd = true;
  }

  // 检查文本是否包含敏感词
  bool containsSensitiveWords(String text) {
    if (!ENABLE_SENSITIVE_WORD_FILTER || text.isEmpty) {
      return false;
    }

    for (int i = 0; i < text.length; i++) {
      DFANode current = root;
      int index = i;
      
      while (index < text.length && current.next.containsKey(text[index])) {
        current = current.next[text[index]]!;
        if (current.isEnd) {
          return true;
        }
        index++;
      }
    }
    return false;
  }

  // 查找所有敏感词
  List<String> findAllSensitiveWords(String text) {
    if (!ENABLE_SENSITIVE_WORD_FILTER || text.isEmpty) {
      return [];
    }

    Set<String> result = {};
    for (int i = 0; i < text.length; i++) {
      DFANode current = root;
      String word = '';
      int index = i;
      
      while (index < text.length && current.next.containsKey(text[index])) {
        current = current.next[text[index]]!;
        word += text[index];
        if (current.isEnd) {
          result.add(word);
          break;
        }
        index++;
      }
    }
    return result.toList();
  }

  // 替换敏感词为 *
  String filterSensitiveWords(String text) {
    if (!ENABLE_SENSITIVE_WORD_FILTER || text.isEmpty) {
      return text;
    }

    String result = text;
    final sensitiveWords = findAllSensitiveWords(text);
    
    for (var word in sensitiveWords) {
      result = result.replaceAll(word, '*' * word.length);
    }
    
    return result;
  }
} 