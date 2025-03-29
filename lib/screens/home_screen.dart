import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../services/database_service.dart';
import '../providers/conversation_provider.dart';

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
        title: const Text('教师助手'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                      ? const Center(
                          child: Text('暂无历史对话'),
                        )
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _conversations[index];
                            return ListTile(
                              title: Text(conversation.title),
                              subtitle: Text(
                                '${conversation.messages.length}条消息 · ${conversation.createdAt.toString().substring(0, 16)}',
                              ),
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
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}