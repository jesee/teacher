import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIModelConfigScreen extends StatefulWidget {
  const AIModelConfigScreen({super.key});

  @override
  State<AIModelConfigScreen> createState() => _AIModelConfigScreenState();
}

class _AIModelConfigScreenState extends State<AIModelConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _modelNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('apiKey') ?? '';
      _apiUrlController.text = prefs.getString('apiUrl') ?? 'https://openrouter.ai/api/v1/chat/completions';
      _modelNameController.text = prefs.getString('modelName') ?? 'google/gemini-2.0-flash-thinking-exp:free';
    });
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apiKey', _apiKeyController.text);
      await prefs.setString('apiUrl', _apiUrlController.text);
      await prefs.setString('modelName', _modelNameController.text);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI模型配置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // API 地址输入框
              TextFormField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API地址',
                  border: const OutlineInputBorder(),
                  hintText: 'https://openrouter.ai/api/v1/chat/completions',
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
                  hintText: 'google/gemini-2.0-flash-thinking-exp:free',
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
                  labelText: 'OpenRouter API密钥',
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
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelNameController.dispose();
    super.dispose();
  }
} 