import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'ai_model_config_screen.dart';

class AIModelListScreen extends StatefulWidget {
  const AIModelListScreen({Key? key}) : super(key: key);

  @override
  State<AIModelListScreen> createState() => _AIModelListScreenState();
}

class _AIModelListScreenState extends State<AIModelListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _modelConfigs = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _hasChanges = false; // 跟踪是否有修改

  @override
  void initState() {
    super.initState();
    _loadModelConfigs();
  }

  Future<void> _loadModelConfigs() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // 确保数据库已初始化
      final db = await _databaseService.database;
      if (!db.isOpen) {
        throw Exception('数据库未正确初始化');
      }
      
      final configs = await _databaseService.getAllAIModelConfigs();
      
      if (!mounted) return;
      setState(() {
        _modelConfigs = configs;
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
        SnackBar(content: Text('加载模型配置失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _setEnabledModel(int id) async {
    try {
      await _databaseService.setEnabledAIModelConfig(id);
      _hasChanges = true; // 标记有修改
      await _loadModelConfigs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已设为当前模型')),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置当前模型失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteModel(int id) async {
    try {
      await _databaseService.deleteAIModelConfig(id);
      _hasChanges = true; // 标记有修改
      await _loadModelConfigs();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除成功')),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 返回时告知前一个页面是否需要刷新
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI模型列表'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, _hasChanges);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIModelConfigScreen(),
                  ),
                );
                
                if (result == true) {
                  _hasChanges = true; // 标记有修改
                  _loadModelConfigs();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('加载失败: $_errorMessage'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadModelConfigs,
                          child: const Text('重试'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIModelConfigScreen(),
                              ),
                            );
                            
                            if (result == true) {
                              _hasChanges = true; // 标记有修改
                              _loadModelConfigs();
                            }
                          },
                          child: const Text('添加新模型'),
                        ),
                      ],
                    ),
                  )
                : _modelConfigs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('还没有保存的模型配置'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AIModelConfigScreen(),
                                  ),
                                );
                                
                                if (result == true) {
                                  _hasChanges = true; // 标记有修改
                                  _loadModelConfigs();
                                }
                              },
                              child: const Text('添加模型配置'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _modelConfigs.length,
                        itemBuilder: (context, index) {
                          final config = _modelConfigs[index];
                          final bool isEnabled = config['isEnabled'] == 1;
                          
                          return ListTile(
                            title: Text(
                              config['customName'] ?? '未命名模型',
                              style: TextStyle(
                                fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(config['modelName'] ?? ''),
                            leading: isEnabled
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.radio_button_unchecked),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AIModelConfigScreen(
                                          existingConfig: config,
                                        ),
                                      ),
                                    );
                                    
                                    if (result == true) {
                                      _hasChanges = true; // 标记有修改
                                      _loadModelConfigs();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('确认删除'),
                                        content: Text('确定要删除模型配置"${config['customName'] ?? '未命名模型'}"吗？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteModel(config['id']);
                                            },
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              if (!isEnabled) {
                                _setEnabledModel(config['id']);
                              }
                            },
                          );
                        },
                      ),
      ),
    );
  }
} 