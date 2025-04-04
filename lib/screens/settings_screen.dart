import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/speech_settings_provider.dart';
import 'speech_settings_screen.dart';
import 'ai_model_config_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
            subtitle: const Text('配置API地址、模型名称和密钥'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIModelConfigScreen(),
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
          
          // 这里可以添加其他设置选项
          // 例如：主题设置、通知设置等
        ],
      ),
    );
  }
} 