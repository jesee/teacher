import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigScreen extends StatefulWidget {
  const ApiConfigScreen({super.key});

  @override
  State<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends State<ApiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  Future<void> _loadSavedKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('apiKey') ?? '';
    });
  }

  Future<void> _saveApiKey() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apiKey', _apiKeyController.text);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API密钥配置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'OpenRouter API密钥',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入有效的API密钥';
                  }
                  if (!value.startsWith('sk-or-v1-')) {
                    return '密钥格式不正确，请检查密钥前缀';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveApiKey,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('保存配置'),
              )
            ],
          ),
        ),
      ),
    );
  }
}