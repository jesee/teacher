import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AIModelConfigScreen extends StatefulWidget {
  final Map<String, dynamic>? existingConfig;

  const AIModelConfigScreen({Key? key, this.existingConfig}) : super(key: key);

  @override
  State<AIModelConfigScreen> createState() => _AIModelConfigScreenState();
}

class _AIModelConfigScreenState extends State<AIModelConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customNameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _modelNameController = TextEditingController();
  
  Map<String, dynamic>? _currentConfig;
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (widget.existingConfig != null) {
        // 如果是编辑现有配置
        _currentConfig = widget.existingConfig;
        _customNameController.text = _currentConfig!['customName'] ?? '';
        _apiKeyController.text = _currentConfig!['apiKey'] ?? '';
        _apiUrlController.text = _currentConfig!['apiUrl'] ?? '';
        _modelNameController.text = _currentConfig!['modelName'] ?? '';
      } else {
        // 如果是新建配置，设置默认值
        _apiUrlController.text = '';
        _modelNameController.text = '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载配置失败: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      try {
        final config = {
          'id': _currentConfig?['id'],
          'customName': _customNameController.text,
          'apiKey': _apiKeyController.text,
          'apiUrl': _apiUrlController.text,
          'modelName': _modelNameController.text,
          'createdAt': DateTime.now().toIso8601String(),
        };
        
        await _databaseService.saveAIModelConfig(config);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('配置保存成功')),
          );
          Navigator.pop(context, true); // 返回true表示配置已更新
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存配置失败: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false); // 返回false表示配置未更新但用户手动返回
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existingConfig != null ? '编辑AI模型配置' : '新增AI模型配置'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, false); // 返回false表示配置未更新
            },
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 自定义名称输入框
                      TextFormField(
                        controller: _customNameController,
                        decoration: InputDecoration(
                          labelText: '自定义名称',
                          border: const OutlineInputBorder(),
                          hintText: '如：Gemini模型',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _customNameController.clear(),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入自定义名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // API 地址输入框
                      TextFormField(
                        controller: _apiUrlController,
                        decoration: InputDecoration(
                          labelText: 'API地址',
                          border: const OutlineInputBorder(),
                          hintText: 'https://api.mistral.ai/v1/chat/completions',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _apiUrlController.clear(),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入API地址';
                          }
                          final uri = Uri.tryParse(value);
                          if (uri == null || !uri.hasAbsolutePath) {
                            return '请输入有效的URL地址';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 模型名称输入框
                      TextFormField(
                        controller: _modelNameController,
                        decoration: InputDecoration(
                          labelText: '模型名称',
                          border: const OutlineInputBorder(),
                          hintText: 'google/gemini-2.0-flash',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _modelNameController.clear(),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入模型名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // API密钥输入框
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'API密钥',
                          border: const OutlineInputBorder(),
                          hintText: 'sk-or-v1-...',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _apiKeyController.clear(),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入API密钥';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // 保存按钮
                      ElevatedButton(
                        onPressed: _saveConfig,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('保存配置'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
} 