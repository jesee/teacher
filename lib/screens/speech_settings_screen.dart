import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/speech_settings_provider.dart';
import '../services/speech_service.dart';

class SpeechSettingsScreen extends StatelessWidget {
  const SpeechSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final speechSettingsProvider = Provider.of<SpeechSettingsProvider>(context);
    final speechService = SpeechService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音设置'),
      ),
      body: ListView(
        children: [
          // 自动朗读开关
          SwitchListTile(
            title: const Text('自动朗读'),
            subtitle: const Text('收到新消息时自动朗读'),
            value: speechSettingsProvider.autoRead,
            onChanged: (bool value) {
              speechSettingsProvider.setAutoRead(value);
            },
          ),
          
          const Divider(),
          
          // 语速设置
          ListTile(
            title: const Text('语速设置'),
            subtitle: Text('当前语速: ${speechSettingsProvider.speechRate}x'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: SpeechSettingsProvider.speechRateOptions.map((rate) {
                return ChoiceChip(
                  label: Text('${rate}x'),
                  selected: speechSettingsProvider.speechRate == rate,
                  onSelected: (bool selected) async {
                    if (selected) {
                      // 更新设置 - 已经包含了对SpeechService的更新
                      await speechSettingsProvider.setSpeechRate(rate);
                      
                      // 播放示例文本以演示效果
                      _speakSample(speechService, rate, speechSettingsProvider.speechPitch);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          
          // 语调设置
          ListTile(
            title: const Text('语调设置'),
            subtitle: Text('当前语调: ${speechSettingsProvider.speechPitch}x'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              children: SpeechSettingsProvider.speechPitchOptions.map((pitch) {
                return ChoiceChip(
                  label: Text('${pitch}x'),
                  selected: speechSettingsProvider.speechPitch == pitch,
                  onSelected: (bool selected) async {
                    if (selected) {
                      // 更新设置 - 已经包含了对SpeechService的更新
                      await speechSettingsProvider.setSpeechPitch(pitch);
                      
                      // 播放示例文本以演示效果
                      _speakSample(speechService, speechSettingsProvider.speechRate, pitch);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 测试按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () {
                // 播放示例文本
                _speakSample(
                  speechService, 
                  speechSettingsProvider.speechRate, 
                  speechSettingsProvider.speechPitch
                );
              },
              child: const Text('测试当前语音设置'),
            ),
          ),
        ],
      ),
    );
  }

  // 播放示例文本
  void _speakSample(SpeechService speechService, double rate, double pitch) {
    speechService.speak(
      '这是语音合成的示例文本',
      language: 'zh-CN',
      rate: rate,
      pitch: pitch,
    );
  }
} 