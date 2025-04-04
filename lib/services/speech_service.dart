import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';

import 'package:flutter_tts/flutter_tts.dart';

class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  String? _currentPlayingId;
  String? get currentPlayingId => _currentPlayingId;

  double _currentRate = 0.4;
  double _currentPitch = 1.0;
  String _currentLanguage = "en-US";

  Future<void> setRate(double rate) async {
    debugPrint('设置语速: $rate');
    _currentRate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    debugPrint('设置语调: $pitch');
    _currentPitch = pitch;
    await _tts.setPitch(pitch);
  }

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    await _tts.setLanguage(language);
  }

  Future<void> initializeTts() async {
    debugPrint('初始化TTS引擎，当前语言: $_currentLanguage, 语速: $_currentRate, 语调: $_currentPitch');
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_currentRate);
    await _tts.setPitch(_currentPitch);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _onPlayingStateChanged?.call(_isPlaying);
    });
    debugPrint('TTS引擎初始化完成');
  }

  Function(bool)? _onPlayingStateChanged;
  void setOnPlayingStateChanged(Function(bool) callback) {
    _onPlayingStateChanged = callback;
  }

  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 1.0,
    double pitch = 1.0,
    String? utteranceId,
  }) async {
    if (_isPlaying && utteranceId == _currentPlayingId) {
      await stop();
      return;
    }
    
    if (_isPlaying) {
      await stop();
    }
    
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    
    _isPlaying = true;
    _currentPlayingId = utteranceId;
    _onPlayingStateChanged?.call(_isPlaying);
    
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _currentPlayingId = null;
    _onPlayingStateChanged?.call(_isPlaying);
  }
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;

  SpeechService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_currentRate);
    await _tts.setPitch(_currentPitch);
    await _tts.setVolume(1.0);
    
    // 设置完成回调
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _currentPlayingId = null;
      _onPlayingStateChanged?.call(_isPlaying);
    });
  }

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool get isListening => _isListening;

  static const platform = MethodChannel('com.example.teacher/speech');
  bool _useNativeSpeech = false;

  // 添加错误回调
  Function(String)? _onSpeechError;
  void setOnSpeechError(Function(String) callback) {
    _onSpeechError = callback;
  }

  Future<bool> initialize() async {
    try {
      debugPrint('正在初始化语音识别服务...');
      // 初始化TTS
      await initializeTts();
      
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
          // 通知外部语音识别出错
          if (_onSpeechError != null) {
            _onSpeechError!(errorNotification.errorMsg);
          }
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
        
        // 创建符合新API的SpeechListenOptions对象
        final options = stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
        );
        
        // 将options作为listenOptions参数传递，其他参数直接传递给listen方法
        await _speech.listen(
          onResult: (result) {
            debugPrint('识别结果: ${result.recognizedWords} (是否最终结果: ${result.finalResult})');
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              onResult(result.recognizedWords);
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
          localeId: 'zh_CN',
          listenOptions: options,
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
    debugPrint('SpeechService: 开始停止语音识别...');
    
    try {
      if (_useNativeSpeech) {
        try {
          debugPrint('SpeechService: 停止Android原生语音识别');
          await platform.invokeMethod('stopSpeechRecognition');
        } catch (e) {
          debugPrint('SpeechService: 停止Android原生语音识别失败: $e');
        }
      } else if (_speech.isListening) {
        debugPrint('SpeechService: 停止speech_to_text语音识别');
        await _speech.stop();
        debugPrint('SpeechService: speech_to_text语音识别已停止');
      } else {
        debugPrint('SpeechService: speech_to_text不在监听状态，无需停止');
      }
    } catch (e) {
      debugPrint('SpeechService: 停止语音识别时发生异常: $e');
    } finally {
      // 无论如何都要确保isListening标志被设置为false
      _isListening = false;
      debugPrint('SpeechService: isListening设置为false');
    }
    
    // 如果服务还在监听，尝试强制重置
    if (_speech.isListening) {
      debugPrint('SpeechService: 检测到语音服务仍在监听状态，尝试强制重置');
      try {
        // 尝试再次停止
        await _speech.stop();
      } catch (e) {
        debugPrint('SpeechService: 强制停止失败: $e');
      }
    }
    
    debugPrint('SpeechService: 停止语音识别完成，当前状态: isListening=$isListening');
  }

  Future<void> openAppSettings() async {
    await AppSettings.openAppSettings();
  }
}