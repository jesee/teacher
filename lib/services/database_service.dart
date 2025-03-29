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
}