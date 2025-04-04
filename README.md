# AI 教师助手

AI 教师助手是一款基于 Flutter 开发的移动应用，旨在通过人工智能技术为用户提供个性化的学习体验。应用集成了语音识别、文本转语音以及 AI 对话功能，帮助用户高效地进行学习和提问。

## 主要功能

- **AI 对话**: 集成 AI 模型，提供智能化的教学辅助和问答服务
- **语音识别**: 支持语音输入，方便用户进行快速提问
- **文本转语音**: 将 AI 的回答转换为语音，提供更自然的交互体验
- **历史对话管理**: 记录和管理所有历史对话，方便用户回顾和继续之前的学习
- **设置自定义**: 允许用户配置 AI 模型参数、语音设置等

## 技术特点

- 使用 Flutter 框架实现跨平台兼容
- 采用 Provider 进行状态管理
- 使用 SQLite 进行本地数据存储
- 集成 speech_to_text 和 flutter_tts 实现语音功能
- Markdown 渲染支持，优化代码块显示

## 开始使用

### 环境要求

- Flutter SDK 3.7.0 或更高版本
- Dart SDK 3.0.0 或更高版本

### 安装

1. 克隆项目到本地:
```bash
git clone https://your-repository-url/teacher.git
cd teacher
```

2. 安装依赖:
```bash
flutter pub get
```

3. 运行应用:
```bash
flutter run
```

## 项目结构

- `lib/`
  - `main.dart` - 应用入口
  - `screens/` - 界面组件，包含主界面、对话界面和设置界面
  - `widgets/` - 可复用的小型组件
  - `providers/` - 状态管理
  - `services/` - 服务实现，包括 AI 服务、语音服务和数据库服务
  - `models/` - 数据模型

## 配置说明

首次使用前，需要在设置中配置 AI 模型:
1. 打开应用并进入设置页面
2. 配置 API URL、API Key 和模型名称
3. 根据需要调整语音速率和音调

## 许可证

[添加您的许可证信息]

## 贡献

欢迎通过 Issues 和 Pull Requests 进行贡献，请确保您遵循项目的代码规范和提交规范。

## 联系方式

[添加联系方式或支持渠道]

代办事项：
1、添加收费模块，计费需要考虑代码安全性，失效验证等
2、上线准备