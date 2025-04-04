import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/conversation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'teacher_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onOpen: (db) async {
        // 检查是否已存在 Mistral 配置
        final List<Map<String, dynamic>> configs = await db.query(
          'ai_model_configs',
          where: 'customName = ?',
          whereArgs: ['mistral'],
        );
        
        // 如果不存在，则添加 Mistral 配置
        if (configs.isEmpty) {
          await db.insert('ai_model_configs', {
            'customName': 'mistral',
            'apiUrl': 'https://api.mistral.ai/v1/chat/completions',
            'modelName': 'mistral-large-latest',
            'apiKey': 'IBty6B2PCK0fSt7MjErPBnWONBlbNOTl',
            'isEnabled': 1,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversationId INTEGER,
        content TEXT,
        isUser INTEGER,
        timestamp TEXT,
        FOREIGN KEY (conversationId) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');
    
    // 新增AI模型配置表
    await db.execute('''
      CREATE TABLE ai_model_configs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customName TEXT UNIQUE,
        apiUrl TEXT,
        modelName TEXT,
        apiKey TEXT,
        isEnabled INTEGER DEFAULT 0,
        createdAt TEXT
      )
    ''');
  }

  // 保存对话
  Future<int> saveConversation(Conversation conversation) async {
    final db = await database;
    int id;
    
    if (conversation.id != null) {
      // 更新现有对话
      await db.update(
        'conversations',
        conversation.toMap(),
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
      id = conversation.id!;
      
      // 删除旧消息
      await db.delete(
        'messages',
        where: 'conversationId = ?',
        whereArgs: [id],
      );
    } else {
      // 创建新对话
      id = await db.insert('conversations', conversation.toMap());
    }
    
    // 插入新消息
    for (var message in conversation.messages) {
      await db.insert('messages', {
        ...message.toMap(),
        'conversationId': id,
      });
    }
    
    return id;
  }

  // 添加消息到对话
  Future<int> addMessage(Message message) async {
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  // 获取所有对话
  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> conversationMaps = await db.query('conversations', orderBy: 'createdAt DESC');
    
    List<Conversation> conversations = [];
    
    for (var conversationMap in conversationMaps) {
      final List<Map<String, dynamic>> messageMaps = await db.query(
        'messages',
        where: 'conversationId = ?',
        whereArgs: [conversationMap['id']],
        orderBy: 'timestamp ASC'
      );
      
      List<Message> messages = messageMaps.map((messageMap) => Message.fromMap(messageMap)).toList();
      
      conversations.add(Conversation.fromMap(conversationMap, messages));
    }
    
    return conversations;
  }

  // 获取单个对话
  Future<Conversation?> getConversation(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> conversationMaps = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (conversationMaps.isEmpty) {
      return null;
    }
    
    final List<Map<String, dynamic>> messageMaps = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [id],
      orderBy: 'timestamp ASC'
    );
    
    List<Message> messages = messageMaps.map((messageMap) => Message.fromMap(messageMap)).toList();
    
    return Conversation.fromMap(conversationMaps.first, messages);
  }

  // 删除对话
  Future<int> deleteConversation(int id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 更新对话标题
  Future<void> updateConversationTitle(int id, String newTitle) async {
    final db = await database;
    await db.update(
      'conversations',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 保存AI模型配置
  Future<int> saveAIModelConfig(Map<String, dynamic> config) async {
    final db = await database;
    
    // 检查是否已存在相同自定义名称的配置
    final List<Map<String, dynamic>> existingConfigs = await db.query(
      'ai_model_configs',
      where: 'customName = ? AND id != ?',
      whereArgs: [config['customName'], config['id'] ?? -1],
    );
    
    if (existingConfigs.isNotEmpty) {
      throw Exception('已存在相同名称的配置，请更换名称');
    }
    
    // 如果这是第一个配置，则设置为启用
    final List<Map<String, dynamic>> allConfigs = await db.query('ai_model_configs');
    if (allConfigs.isEmpty) {
      config['isEnabled'] = 1;
    }
    
    int id;
    if (config['id'] != null) {
      // 更新现有配置
      await db.update(
        'ai_model_configs',
        config,
        where: 'id = ?',
        whereArgs: [config['id']],
      );
      id = config['id'];
    } else {
      // 创建新配置
      id = await db.insert('ai_model_configs', config);
    }
    
    return id;
  }

  // 获取所有AI模型配置
  Future<List<Map<String, dynamic>>> getAllAIModelConfigs() async {
    final db = await database;
    return await db.query('ai_model_configs', orderBy: 'createdAt DESC');
  }

  // 获取当前启用的AI模型配置
  Future<Map<String, dynamic>?> getEnabledAIModelConfig() async {
    final db = await database;
    final List<Map<String, dynamic>> configs = await db.query(
      'ai_model_configs',
      where: 'isEnabled = 1',
    );
    
    if (configs.isEmpty) {
      return null;
    }
    return configs.first;
  }

  // 设置启用的AI模型配置
  Future<void> setEnabledAIModelConfig(int id) async {
    final db = await database;
    
    // 先禁用所有配置
    await db.update(
      'ai_model_configs',
      {'isEnabled': 0},
    );
    
    // 再启用指定的配置
    await db.update(
      'ai_model_configs',
      {'isEnabled': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 删除AI模型配置
  Future<void> deleteAIModelConfig(int id) async {
    final db = await database;
    
    // 检查是否是启用的配置
    final List<Map<String, dynamic>> enabledConfigs = await db.query(
      'ai_model_configs',
      where: 'id = ? AND isEnabled = 1',
      whereArgs: [id],
    );
    
    await db.delete(
      'ai_model_configs',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // 如果删除的是启用的配置，且还有其他配置，则启用最新的配置
    if (enabledConfigs.isNotEmpty) {
      final List<Map<String, dynamic>> remainingConfigs = await db.query(
        'ai_model_configs',
        orderBy: 'createdAt DESC',
      );
      
      if (remainingConfigs.isNotEmpty) {
        await setEnabledAIModelConfig(remainingConfigs.first['id']);
      }
    }
  }
}