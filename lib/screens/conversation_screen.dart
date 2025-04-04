import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/speech_settings_provider.dart';
import '../services/ai_service.dart';
import '../models/conversation.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../widgets/voice_input_bar.dart';

// 自定义代码块构建器
class CustomCodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CustomCodeBlockBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.substring(9); // 移除 'language-' 前缀
    }

    final String code = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (language.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                language,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    // 显示复制成功提示
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('代码已复制到剪贴板'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: '复制代码',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  bool _showVoiceInput = false;

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
          
          // 额外添加一个延时滚动，确保滚动生效
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _scrollToBottom();
            }
          });
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
      setState(() {
        _showVoiceInput = false;
      });
      return;
    }

    // 显示语音输入栏而不是直接开始识别
    setState(() {
      _showVoiceInput = true;
    });
  }

  // 处理取消语音输入
  void _handleVoiceInputCancel() {
    setState(() {
      _showVoiceInput = false;
    });
  }
  
  // 处理发送语音输入的内容
  void _handleVoiceInputSend() async {
    if (_textController.text.isEmpty) {
      setState(() {
        _showVoiceInput = false;
      });
      return;
    }
    
    final currentText = _textController.text;
    _textController.clear();
    
    setState(() {
      _showVoiceInput = false;
    });
    
    // 发送消息到AI
    final provider = context.read<ConversationProvider>();
    await provider.addMessage(Message(content: currentText, isUser: true, timestamp: DateTime.now()));
    
    // 等待AI回复完成
    while (provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // 检查是否自动朗读AI回复
    if (provider.messages.isNotEmpty && !provider.messages.last.isUser) {
      final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
      if (settings.autoRead) {
        await _speechService.speak(
          provider.messages.last.content,
          language: 'zh-CN',
          rate: settings.speechRate,
          pitch: settings.speechPitch,
          utteranceId: 'message_${provider.messages.last.id}'
        );
      }
    }
  }

  // 处理语音识别文本变更
  void _handleVoiceTextChanged(String text) {
    // 这里只需要更新文本控制器，VoiceInputBar内部已经处理了
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
                            child: _buildMessageBubble(message),
                          ),
                        );
                      },
                      // 列表构建完成后尝试滚动到底部
                      addAutomaticKeepAlives: true,
                    ),
                    // 当消息列表变化且不为空时，滚动到底部
                    if (provider.messages.isNotEmpty)
                      Builder(builder: (context) {
                        // 使用Builder确保在布局完成后运行
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });
                        return const SizedBox.shrink(); // 不显示任何内容的小部件
                      }),
                    if (provider.isLoading)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(), // 保留结构但不显示任何内容
                      ),
                  ],
                );
              },
            ),
          ),
          if (_showVoiceInput)
            VoiceInputBar(
              textController: _textController,
              speechService: _speechService,
              onTextChanged: _handleVoiceTextChanged,
              onCancel: _handleVoiceInputCancel,
              onSend: _handleVoiceInputSend,
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.mic_none),
                    onPressed: _startListening,
                    tooltip: '语音输入',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    padding: const EdgeInsets.all(10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '输入您的问题...',
                        border: const OutlineInputBorder(),
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
                                utteranceId: 'message_${provider.messages.last.id}'
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
                              utteranceId: 'message_${provider.messages.last.id}'
                            );
                          }
                        }
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    padding: const EdgeInsets.all(10),
                    tooltip: '发送',
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

  Widget _buildMessageContent(Message message) {
    if (message.isLoading) {
      return Row(
        children: [
          const Text("AI正在思考"),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildBouncingDot(index),
            )),
          ),
        ],
      );
    }

    final messageId = 'message_${message.id}';
    final isCurrentlyPlaying = _speechService.isPlaying && _speechService.currentPlayingId == messageId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: MarkdownBody(
            data: message.content,
            selectable: false,
            shrinkWrap: true,
            builders: {
              'code': CustomCodeBlockBuilder(context),
            },
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 16),
              code: const TextStyle(
                backgroundColor: Colors.black12,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                // color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (!message.isUser)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton(
              icon: Icon(
                isCurrentlyPlaying ? Icons.stop : Icons.volume_up,
                size: 20,
                color: isCurrentlyPlaying ? Colors.blue : null,
              ),
              onPressed: () async {
                final settings = Provider.of<SpeechSettingsProvider>(context, listen: false);
                await _speechService.speak(
                  message.content,
                  language: 'zh-CN',
                  rate: settings.speechRate,
                  pitch: settings.speechPitch,
                  utteranceId: messageId,
                );
                // 强制刷新UI以更新图标状态
                if (mounted) setState(() {});
              },
              tooltip: isCurrentlyPlaying ? '停止播放' : '朗读消息',
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.blue[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessageContent(message),
        ],
      ),
    );
  }

  // 滚动到底部的方法
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // 增加延迟时间，确保ListView已经完成渲染
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      // 如果ScrollController还没有clients，等待框架下一帧再尝试滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }
}