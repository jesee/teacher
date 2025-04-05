import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

class DFANode {
  Map<String, DFANode> children = {};
  bool isEndOfWord = false;
}

class SensitiveWordService {
  static const bool ENABLE_SENSITIVE_WORD_FILTER = false; // 敏感词过滤开关，true表示开启过滤，false表示关闭过滤
  
  static final SensitiveWordService _instance = SensitiveWordService._internal();
  factory SensitiveWordService() => _instance;
  SensitiveWordService._internal();

  DFANode root = DFANode();
  bool _isInitialized = false;
  Set<String> _sensitiveWords = {};

  // 初始化DFA
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 从文件加载敏感词
      final String sensitiveWordsString = await rootBundle.loadString('assets/sensitive_words/sensitive_words.txt');
      final List<String> sensitiveWords = sensitiveWordsString.split('\n')
        .where((word) => word.trim().isNotEmpty)
        .toList();
      
      // 构建DFA
      for (var word in sensitiveWords) {
        _addWord(word.trim());
      }
      
      _isInitialized = true;
    } catch (e) {
      print('Error loading sensitive words: $e');
      _isInitialized = true; // 即使加载失败也标记为已初始化，避免重复尝试
    }
  }

  // 添加单词到DFA
  void _addWord(String word) {
    var current = root;
    for (var char in word.toLowerCase().characters) {
      current.children.putIfAbsent(char, () => DFANode());
      current = current.children[char]!;
    }
    current.isEndOfWord = true;
  }

  // 检查文本是否包含敏感词
  Future<bool> containsSensitiveWord(String text) async {
    await initialize();
    return _checkText(text);
  }

  bool _checkText(String text) {
    if (!_isInitialized) {
      print('Warning: SensitiveWordService not initialized');
      return false;
    }

    final lowerText = text.toLowerCase();
    for (var i = 0; i < lowerText.length; i++) {
      var current = root;
      var j = i;
      while (j < lowerText.length && current.children.containsKey(lowerText[j])) {
        current = current.children[lowerText[j]]!;
        if (current.isEndOfWord) {
          return true;
        }
        j++;
      }
    }
    return false;
  }

  // 过滤文本中的敏感词
  String filterSensitiveWords(String text) {
    if (!_isInitialized) {
      print('Warning: SensitiveWordService not initialized');
      return text;
    }

    var result = text;
    var lowerText = text.toLowerCase();
    var positions = <MapEntry<int, int>>[];

    for (var i = 0; i < lowerText.length; i++) {
      var current = root;
      var j = i;
      var lastEndPos = -1;

      while (j < lowerText.length && current.children.containsKey(lowerText[j])) {
        current = current.children[lowerText[j]]!;
        if (current.isEndOfWord) {
          lastEndPos = j;
        }
        j++;
      }

      if (lastEndPos != -1) {
        positions.add(MapEntry(i, lastEndPos + 1));
        i = lastEndPos;
      }
    }

    // 从后向前替换，避免位置改变
    for (var pos in positions.reversed) {
      var start = pos.key;
      var end = pos.value;
      var length = end - start;
      result = result.replaceRange(start, end, '*' * length);
    }

    return result;
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
      
      while (index < text.length && current.children.containsKey(text[index])) {
        current = current.children[text[index]]!;
        word += text[index];
        if (current.isEndOfWord) {
          result.add(word);
          break;
        }
        index++;
      }
    }
    return result.toList();
  }
} 