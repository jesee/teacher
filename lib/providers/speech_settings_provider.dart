import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/speech_service.dart';

class SpeechSettingsProvider with ChangeNotifier {
  bool _autoRead = false;
  double _speechRate = 1.0;
  double _speechPitch = 1.0;
  
  bool get autoRead => _autoRead;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;
  
  // 预设语速选项
  static const List<double> speechRateOptions = [0.3, 0.5, 0.7, 1.0, 1.3, 1.5];
  
  // 预设语调选项
  static const List<double> speechPitchOptions = [0.3, 0.5, 0.7, 1.0, 1.3, 1.5];
  
  // 构造函数，加载保存的设置
  SpeechSettingsProvider() {
    _loadSettings();
  }
  
  // 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRead = prefs.getBool('auto_read') ?? false;
    _speechRate = prefs.getDouble('speech_rate') ?? 1.0;
    _speechPitch = prefs.getDouble('speech_pitch') ?? 1.0;
    notifyListeners();
    
    // 初始化语音服务
    try {
      final speechService = SpeechService();
      await speechService.setRate(_speechRate);
      await speechService.setPitch(_speechPitch);
    } catch (e) {
      print('初始化语音设置失败: $e');
    }
  }
  
  // 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_read', _autoRead);
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setDouble('speech_pitch', _speechPitch);
  }
  
  // 更新自动朗读设置
  void setAutoRead(bool value) {
    _autoRead = value;
    _saveSettings();
    notifyListeners();
  }
  
  // 更新语速设置
  Future<void> setSpeechRate(double value) async {
    _speechRate = value;
    await _saveSettings();
    
    // 直接应用到语音服务
    try {
      final speechService = SpeechService();
      await speechService.setRate(value);
    } catch (e) {
      print('更新语速设置失败: $e');
    }
    
    notifyListeners();
  }
  
  // 更新语调设置
  Future<void> setSpeechPitch(double value) async {
    _speechPitch = value;
    await _saveSettings();
    
    // 直接应用到语音服务
    try {
      final speechService = SpeechService();
      await speechService.setPitch(value);
    } catch (e) {
      print('更新语调设置失败: $e');
    }
    
    notifyListeners();
  }
} 