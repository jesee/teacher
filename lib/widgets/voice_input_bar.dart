import 'dart:async';
import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import 'audio_waveform.dart';

class VoiceInputBar extends StatefulWidget {
  final TextEditingController textController;
  final SpeechService speechService;
  final Function(String) onTextChanged;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const VoiceInputBar({
    Key? key,
    required this.textController,
    required this.speechService,
    required this.onTextChanged,
    required this.onCancel,
    required this.onSend,
  }) : super(key: key);

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar> {
  bool _isListening = false;
  String _currentText = '';
  Timer? _statusCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _currentText = widget.textController.text;
    
    // 检查语音服务是否已经在监听
    setState(() {
      _isListening = widget.speechService.isListening;
    });
    
    // 启动定期检查计时器
    _startPeriodicCheck();
    
    // 如果需要，开始监听
    if (!_isListening) {
      _startListening();
    }
  }
  
  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
  
  // 定期检查语音识别状态，确保它在运行
  void _startPeriodicCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _isListening && !widget.speechService.isListening) {
        debugPrint('定期检查：语音识别已停止，尝试重新启动');
        _forcedRestartListening();
      }
    });
  }
  
  // 强制重启语音识别，无论当前状态如何
  void _forcedRestartListening() async {
    if (!mounted || !_isListening) return;
    
    try {
      // 先确保语音服务已停止
      if (widget.speechService.isListening) {
        await widget.speechService.stopListening();
      }
      
      // 短暂延迟后重新开始
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted && _isListening) {
        _startListening();
      }
    } catch (e) {
      debugPrint('强制重启语音识别失败: $e');
      // 稍后再试
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isListening) {
          _forcedRestartListening();
        }
      });
    }
  }

  void _startListening() async {
    if (widget.speechService.isListening) return;
    
    setState(() {
      _isListening = true;
    });
    
    try {
      await widget.speechService.startListening((text) {
        // 拼接新识别的文本
        if (text.isNotEmpty) {
          setState(() {
            // 如果当前已有文本，则拼接新文本，否则直接设置
            if (_currentText.isNotEmpty) {
              // 检查最后一个字符是否是标点符号
              final lastChar = _currentText[_currentText.length - 1];
              if (lastChar == '.' || lastChar == '。' || 
                  lastChar == '!' || lastChar == '！' || 
                  lastChar == '?' || lastChar == '？' || 
                  lastChar == ',' || lastChar == '，') {
                // 如果是标点符号，不添加额外空格
                _currentText = '$_currentText $text';
              } else {
                // 否则添加空格拼接
                _currentText = '$_currentText $text';
              }
            } else {
              _currentText = text;
            }
            
            widget.textController.text = _currentText;
            widget.onTextChanged(_currentText);
          });
        }
        
        // 不再使用延迟检查，改为使用定期检查机制
        // 自动重启逻辑现在由_startPeriodicCheck处理
      });
    } catch (e) {
      debugPrint('启动语音识别失败: $e');
      setState(() {
        _isListening = false;
      });
      
      // 尝试在失败后稍后重新启动
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isListening) {
          _startListening();
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('语音识别失败: $e')),
      );
    }
  }

  void _restartListening() async {
    if (!mounted || !_isListening) return;
    _forcedRestartListening();
  }

  Future<void> _stopListening() async {
    debugPrint('开始停止语音识别...');
    
    // 先取消计时器
    _statusCheckTimer?.cancel();
    
    try {
      // 先停止语音服务，然后再更新UI状态
      if (widget.speechService.isListening) {
        debugPrint('语音服务正在监听，尝试停止...');
        await widget.speechService.stopListening();
        debugPrint('语音服务停止完成');
      } else {
        debugPrint('语音服务未在监听状态');
      }
      
      // 停止服务后再更新状态
      if (mounted) {
        setState(() {
          _isListening = false;
          debugPrint('更新状态：_isListening = false');
        });
      }
    } catch (e) {
      debugPrint('停止语音识别时发生错误: $e');
      // 即使出错也要确保更新状态
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
    
    // 再次确认语音服务已经停止
    if (widget.speechService.isListening) {
      debugPrint('警告：尝试停止后语音服务仍在监听状态，再次尝试停止');
      try {
        await widget.speechService.stopListening();
      } catch (e) {
        debugPrint('二次停止语音识别时发生错误: $e');
      }
    }
    
    debugPrint('停止语音识别完成，当前状态: isListening=${widget.speechService.isListening}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '正在聆听...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _currentText.isEmpty ? '请说话...' : '继续说话...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: AudioWaveform(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  barCount: 40,
                ),
              ),
            ),
          ),
          if (_currentText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _currentText,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  // 先停止语音识别
                  await _stopListening();
                  // 再执行取消操作
                  widget.onCancel();
                },
                icon: const Icon(Icons.close),
                label: const Text('取消'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(120, 44),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // 先停止语音识别
                  await _stopListening();
                  // 再执行发送操作
                  widget.onSend();
                },
                icon: const Icon(Icons.send),
                label: const Text('发送'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 