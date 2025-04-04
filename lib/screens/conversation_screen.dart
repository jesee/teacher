import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/speech_settings_provider.dart';
import '../services/ai_service.dart';
import '../models/conversation.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SpeechService _speechService = SpeechService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _speechService.setOnPlayingStateChanged((isPlaying) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 设置context给conversationProvider
      final provider = Provider.of<ConversationProvider>(context, listen: false);
      provider.setContext(context);
      
      // 设置消息添加回调，自动滚动到底部
      provider.setOnMessageAdded(() {
        _scrollToBottom();
      });
      
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is int) {
        // 如果传入了conversationId，加载历史对话
        final conversation = await DatabaseService().getConversation(args);
        if (conversation != null && mounted) {
          await context.read<ConversationProvider>().loadConversation(conversation);
          // 滚动到最新消息
          _scrollToBottom();
        }
      } else {
        // 如果是新对话，清空消息列表
        context.read<ConversationProvider>().clearMessages();
      }
      
      // 初始化语音服务
      try {
        await _speechService.initialize();
        
        // 应用保存的设置
        final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
        await _speechService.setRate(settings.speechRate);
        await _speechService.setPitch(settings.speechPitch);
      } catch (e) {
        if (mounted) {
          if (e.toString().contains('需要麦克风权限')) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('需要权限'),
                content: const Text('需要麦克风权限才能使用语音功能，是否前往系统设置？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 跳转到系统设置
                      _speechService.openAppSettings();
                    },
                    child: const Text('去设置'),
                  ),
                ],
              ),
            );
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: '去授权',
                onPressed: () async {
                  try {
                    await _speechService.initialize();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _speechService.stopListening();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final provider = context.read<ConversationProvider>();
    if (_speechService.isListening) {
      await _speechService.stopListening();
      return;
    }

    try {
      await _speechService.startListening((text) async {
        if (text.isNotEmpty && mounted) {
          setState(() {
            _textController.text = text;
          });
          await provider.addMessage(Message(content: text, isUser: true, timestamp: DateTime.now()));
          _textController.clear();

          // 等待AI回复完成（与其他方法保持一致）
          while (provider.isLoading) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          
          // 现在AI回复已完成，检查是否应该自动朗读
          if (provider.messages.isNotEmpty && !provider.messages.last.isUser) {
            final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
            if (settings.autoRead) {
              await _speechService.speak(
                provider.messages.last.content,
                language: 'zh-CN',
                rate: settings.speechRate,
                pitch: settings.speechPitch,
                messageId: provider.messages.last.id
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('与AI助手对话'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        final message = provider.messages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Align(
                            alignment: message.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? Colors.blue[100]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isLoading)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 40,
                                          height: 20,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: List.generate(3, (index) {
                                              return _buildBouncingDot(index);
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('正在思考...', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                      ],
                                    )
                                  else
                                    Text(message.content),
                                  if (!message.isUser && !message.isLoading) ...[  // 只在AI回复且非加载中的消息显示播放/停止按钮
                                    const SizedBox(height: 4.0),
                                    IconButton(
                                      icon: Icon(
                                        (_speechService.isPlaying && _speechService.currentPlayingMessageId == message.id) ? Icons.stop : Icons.play_arrow,
                                        size: 20
                                      ),
                                      onPressed: () async {
                                        if (_speechService.isPlaying && _speechService.currentPlayingMessageId == message.id) {
                                          await _speechService.stop();
                                        } else {
                                          // 获取语音设置
                                          final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
                                          await _speechService.speak(
                                            message.content, 
                                            language: 'zh-CN',
                                            rate: settings.speechRate,
                                            pitch: settings.speechPitch,
                                            messageId: message.id
                                          );
                                        }
                                        setState(() {});
                                      }
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (provider.isLoading)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(), // 保留结构但不显示任何内容
                      ),
                    if (_speechService.isListening)
                      Positioned(
                        top: 16.0,
                        right: 16.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic, color: Colors.white),
                              const SizedBox(width: 8.0),
                              const Text('正在聆听...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: _speechService.isListening ? '正在聆听...' : '输入您的问题...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _speechService.isListening ? Icons.mic : Icons.mic_none,
                          color: _speechService.isListening ? Colors.red : null,
                        ),
                        onPressed: _startListening,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onTap: () {
                      if (_speechService.isListening) {
                        _speechService.stopListening();
                      }
                      if (!_focusNode.hasFocus) {
                        _focusNode.requestFocus();
                      }
                    },
                    onSubmitted: (text) async {
                      if (text.isNotEmpty) {
                        final currentText = text;
                        _textController.clear();
                        
                        // 发送消息到AI
                        final provider = context.read<ConversationProvider>();
                        await provider.addMessage(Message(content: currentText, isUser: true, timestamp: DateTime.now()));
                        
                        // 等待AI回复完成（通过检查isLoading状态）
                        while (provider.isLoading) {
                          await Future.delayed(const Duration(milliseconds: 100));
                        }
                        
                        // 现在AI回复已完成，检查是否自动朗读
                        if (provider.messages.isNotEmpty && !provider.messages.last.isUser) {
                          final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
                          if (settings.autoRead) {
                            await _speechService.speak(
                              provider.messages.last.content,
                              language: 'zh-CN',
                              rate: settings.speechRate,
                              pitch: settings.speechPitch,
                              messageId: provider.messages.last.id
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (_textController.text.isNotEmpty) {
                      final currentText = _textController.text;
                      _textController.clear();
                      
                      // 发送消息到AI
                      final provider = context.read<ConversationProvider>();
                      await provider.addMessage(Message(content: currentText, isUser: true, timestamp: DateTime.now()));
                      
                      // 等待AI回复完成（通过检查isLoading状态）
                      while (provider.isLoading) {
                        await Future.delayed(const Duration(milliseconds: 100));
                      }
                      
                      // 现在AI回复已完成，检查是否自动朗读
                      if (provider.messages.isNotEmpty && !provider.messages.last.isUser) {
                        final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
                        if (settings.autoRead) {
                          await _speechService.speak(
                            provider.messages.last.content,
                            language: 'zh-CN',
                            rate: settings.speechRate,
                            pitch: settings.speechPitch,
                            messageId: provider.messages.last.id
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6 + 4 * ((index == 0 ? value : index == 1 ? (value + 0.3) % 1 : (value + 0.6) % 1) * 0.8),
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }

  // 滚动到底部的方法
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
}