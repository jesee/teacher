import 'package:flutter/material.dart';
import 'package:teacher/services/ai_service.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../services/database_service.dart';
import '../providers/conversation_provider.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final db = await _databaseService.database;
      // 确保数据库已初始化
      if (!db.isOpen) {
        throw Exception('数据库未正确初始化');
      }
      final conversations = await _databaseService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载历史对话失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI学习助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      const Text('加载失败'),
                      const SizedBox(height: 8),
                      Text(_errorMessage, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadConversations,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Text(
                          '历史对话',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/conversation').then((_) {
                              _loadConversations();
                            });
                          },
                          child: const Text('开始新对话'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无历史对话',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/conversation').then((_) {
                                      _loadConversations();
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('开始新对话'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Dismissible(
                                  key: Key(conversation.id.toString()),
                                  direction: DismissDirection.horizontal,
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue[400],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 24.0),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '重命名',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red[400],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24.0),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '删除',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      // 删除操作
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('确认删除'),
                                            content: const Text('确定要删除这个对话吗？'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('取消'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('删除'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    } else {
                                      // 重命名操作
                                      final TextEditingController titleController = TextEditingController(text: conversation.title);
                                      final result = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('重命名对话'),
                                            content: TextField(
                                              controller: titleController,
                                              decoration: const InputDecoration(
                                                labelText: '对话名称',
                                                hintText: '请输入新的对话名称',
                                              ),
                                              autofocus: true,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('取消'),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  if (titleController.text.trim().isNotEmpty) {
                                                    await context.read<ConversationProvider>()
                                                      .renameConversation(conversation.id!, titleController.text.trim());
                                                    if (context.mounted) {
                                                      Navigator.of(context).pop(true);
                                                    }
                                                  }
                                                },
                                                child: const Text('保存'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (result == true) {
                                        _loadConversations();
                                      }
                                      return false;
                                    }
                                  },
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      await context.read<ConversationProvider>().deleteConversation(conversation.id!);
                                      _loadConversations();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('对话已删除')),
                                        );
                                      }
                                    }
                                  },
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        if (!mounted) return;
                                        Navigator.pushNamed(
                                          context,
                                          '/conversation',
                                          arguments: conversation.id,
                                        ).then((_) {
                                          _loadConversations();
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    conversation.title,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.chat_bubble_outline,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${conversation.messages.length}条消息',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  conversation.createdAt.toString().substring(0, 16),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
    );
  }
}