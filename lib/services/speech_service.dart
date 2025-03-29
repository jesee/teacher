import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';

import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  int? _currentPlayingMessageId;
  int? get currentPlayingMessageId => _currentPlayingMessageId;

  double _currentRate = 0.4;
  String _currentLanguage = "en-US";

  Future<void> setRate(double rate) async {
    _currentRate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _tts.setLanguage(language);
  }

  Future<void> initializeTts() async {
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_currentRate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _onPlayingStateChanged?.call(_isPlaying);
    });
  }

  Function(bool)? _onPlayingStateChanged;
  void setOnPlayingStateChanged(Function(bool) callback) {
    _onPlayingStateChanged = callback;
  }

  Future<void> speak(String text, {String language = "en-US", double rate = 0.4, int? messageId}) async {
    try {
      if (_isPlaying) {
        await stop();
      }
      _currentPlayingMessageId = messageId;
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      _isPlaying = true;
      _onPlayingStateChanged?.call(_isPlaying);
      await _tts.speak(text);
    } catch (e) {
      _isPlaying = false;
      throw Exception('语音播放失败: $e');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _currentPlayingMessageId = null;
    _onPlayingStateChanged?.call(_isPlaying);
  }
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;

  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool get isListening => _isListening;

  static const platform = MethodChannel('com.example.teacher/speech');
  bool _useNativeSpeech = false;

  Future<bool> initialize() async {
    try {
      debugPrint('正在初始化语音识别服务...');
      // 首先尝试初始化speech_to_text
      final isSupported = await _speech.initialize(
        onStatus: (status) {
          debugPrint('语音识别状态: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
        onError: (errorNotification) {
          debugPrint('语音识别错误: ${errorNotification.errorMsg}');
          _isListening = false;
        },
      );

      if (!isSupported) {
        debugPrint('speech_to_text不可用，尝试使用Android原生语音识别...');
        try {
          final bool nativeSupported = await platform.invokeMethod('checkSpeechRecognition');
          if (nativeSupported) {
            _useNativeSpeech = true;
            debugPrint('Android原生语音识别可用');
            return true;
          }
        } catch (e) {
          debugPrint('检查Android原生语音识别失败: $e');
        }
        return false;
      }

      // 检查麦克风权限
      final hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        debugPrint('需要麦克风权限才能使用语音功能');
        return false;
      }

      debugPrint('语音识别服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('语音识别初始化错误: $e');
      return false;
    }
  }

  Future<bool> startListening(Function(String) onResult) async {
    if (_useNativeSpeech) {
      try {
        debugPrint('使用Android原生语音识别...');
        _isListening = true;
        final String result = await platform.invokeMethod('startSpeechRecognition');
        _isListening = false;
        if (result.isNotEmpty) {
          onResult(result);
          return true;
        }
        return false;
      } catch (e) {
        debugPrint('Android原生语音识别失败: $e');
        _isListening = false;
        return false;
      }
    }

    if (!_speech.isAvailable) {
      debugPrint('语音服务未初始化，尝试初始化...');
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('语音服务初始化失败');
        return false;
      }
    }

    if (!_speech.isListening) {
      try {
        debugPrint('开始语音识别...');
        _isListening = true;
        await _speech.listen(
          localeId: 'zh_CN',
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
          onResult: (result) {
            debugPrint('识别结果: ${result.recognizedWords} (是否最终结果: ${result.finalResult})');
            if (result.finalResult) {
              onResult(result.recognizedWords);
              _isListening = false;
            }
          },
        );
        return true;
      } catch (e) {
        debugPrint('语音识别启动失败: $e');
        _isListening = false;
        return false;
      }
    } else {
      debugPrint('语音识别已经在运行中');
    }
    return true;
  }

  Future<void> stopListening() async {
    if (_useNativeSpeech) {
      try {
        await platform.invokeMethod('stopSpeechRecognition');
      } catch (e) {
        debugPrint('停止Android原生语音识别失败: $e');
      }
    } else {
      await _speech.stop();
    }
    _isListening = false;
  }

  Future<void> openAppSettings() async {
    await AppSettings.openAppSettings();
  }
}