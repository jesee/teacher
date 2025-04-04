import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/speech_settings_provider.dart';
import '../services/database_service.dart';
import 'speech_settings_screen.dart';
import 'ai_model_config_screen.dart';
import 'ai_model_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Map<String, dynamic>? _currentModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentModel();
  }

  Future<void> _loadCurrentModel() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final model = await _databaseService.getEnabledAIModelConfig();
      setState(() {
        _currentModel = model;
        _isLoading = false;
      });
    } catch (e) {
      print('加载当前模型失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // AI模型配置入口
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('AI模型配置'),
            subtitle: _isLoading
                ? const Text('加载中...')
                : Text('当前模型：${_currentModel != null ? _currentModel!['customName'] : "无"}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIModelListScreen(),
                ),
              );
            },
          ),
          const Divider(),
          
          // 语音设置入口
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('语音设置'),
            subtitle: const Text('设置语音朗读、语速和语调'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpeechSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          
          // 版本信息
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本信息'),
            subtitle: const Text('v1.0.0'),
          ),
          const Divider(),
          
          // 这里可以添加其他设置选项
          // 例如：主题设置、通知设置等
        ],
      ),
    );
  }
} 