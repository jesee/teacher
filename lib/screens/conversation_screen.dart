import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../services/ai_service.dart';
import '../models/conversation.dart';
import '../services/speech_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is int) {
        // 如果传入了conversationId，加载历史对话
        final conversation = await DatabaseService().getConversation(args);
        if (conversation != null && mounted) {
          await context.read<ConversationProvider>().loadConversation(conversation);
        }
      } else {
        // 如果是新对话，清空消息列表
        context.read<ConversationProvider>().clearMessages();
      }
      
      // 初始化语音服务
      try {
        await _speechService.initialize();
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
          provider.addMessage(Message(content: text, isUser: true, timestamp: DateTime.now()));
          _textController.clear();

          // 处理AI回复并播放语音
          try {
            final responseText = await AIService().getAIResponse(text, provider.messages.map((m) => m.toMap()).toList());
          provider.addMessage(
            Message(
              content: responseText,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
            await _speechService.speak(responseText);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI回复失败: $e'))
            );
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
                              child: Text(message.content),
                            ),
                          ),
                        );
                      },
                    ),
                    if (provider.isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
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
                    onSubmitted: (text) {
  if (text.isNotEmpty) {
    context.read<ConversationProvider>().addMessage(Message(content: text, isUser: true, timestamp: DateTime.now()));
    _textController.clear();
  }
},
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      context.read<ConversationProvider>().addMessage(Message(content: _textController.text, isUser: true, timestamp: DateTime.now()));
                      _textController.clear();
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
}