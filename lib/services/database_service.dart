import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'annadanam.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ========== CREATE ALL TABLES ==========
  Future<void> _createTables(Database db, int version) async {
    // Batch execute all table creations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        last_login TEXT,
        created_at TEXT,
        additional_info TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_donations(
        id TEXT PRIMARY KEY,
        donor_id TEXT NOT NULL,
        donor_name TEXT NOT NULL,
        food_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        servings INTEGER,
        description TEXT,
        is_veg INTEGER DEFAULT 1,
        pickup_date TEXT NOT NULL,
        pickup_time TEXT NOT NULL,
        address TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        special_instructions TEXT,
        has_allergens INTEGER DEFAULT 0,
        allergens TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (donor_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_requests(
        id TEXT PRIMARY KEY,
        recipient_id TEXT NOT NULL,
        recipient_name TEXT NOT NULL,
        number_of_people INTEGER NOT NULL,
        address TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        preferred_date TEXT NOT NULL,
        preferred_time TEXT NOT NULL,
        special_requirements TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS volunteer_tasks(
        id TEXT PRIMARY KEY,
        volunteer_id TEXT NOT NULL,
        donation_id TEXT,
        request_id TEXT,
        task_type TEXT NOT NULL,
        location TEXT NOT NULL,
        pickup_time TEXT,
        delivery_time TEXT,
        status TEXT DEFAULT 'assigned',
        notes TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY (volunteer_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (donation_id) REFERENCES food_donations(id) ON DELETE SET NULL,
        FOREIGN KEY (request_id) REFERENCES food_requests(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS deliveries(
        id TEXT PRIMARY KEY,
        donation_id TEXT NOT NULL,
        request_id TEXT NOT NULL,
        volunteer_id TEXT NOT NULL,
        pickup_time TEXT,
        delivery_time TEXT,
        status TEXT DEFAULT 'pending',
        rating REAL,
        feedback TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY (donation_id) REFERENCES food_donations(id) ON DELETE CASCADE,
        FOREIGN KEY (request_id) REFERENCES food_requests(id) ON DELETE CASCADE,
        FOREIGN KEY (volunteer_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        data TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chats(
        id TEXT PRIMARY KEY,
        user1Id TEXT NOT NULL,
        user2Id TEXT NOT NULL,
        user1Name TEXT,
        user2Name TEXT,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderName TEXT,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'sent',
        FOREIGN KEY (chatId) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    print('✅ All database tables created successfully!');
  }

  // ========== DATABASE UTILITIES ==========
  Future<void> closeDatabase() async {  // Renamed from close()
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabaseFile() async {  // Renamed from deleteDatabase()
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'annadanam.db');
    await deleteDatabase(path);
    print('🗑️ Database deleted');
  }

  Future<void> resetDatabase() async {
    await deleteDatabaseFile();
    _database = null;
    await database;
    print('🔄 Database reset complete');
  }

  // ========== CHAT LOCAL STORAGE METHODS ==========
  Future<void> saveLocalMessage(Map<String, dynamic> message) async {
    final db = await database;
    
    // Ensure chat exists first to satisfy foreign key (or ignore FK for local cache)
    // We'll just insert a stub chat if it doesn't exist
    final chatId = message['chatId']?.toString();
    if (chatId == null) return;

    final existingChat = await db.query('chats', where: 'id = ?', whereArgs: [chatId]);
    if (existingChat.isEmpty) {
      await db.insert('chats', {
        'id': chatId,
        'user1Id': 'unknown',
        'user2Id': 'unknown',
        'created_at': DateTime.now().toIso8601String(),
        'lastMessage': message['text'],
        'lastMessageTime': message['timestamp'],
      });
    }

    await db.insert(
      'messages',
      {
        'id': (message['id'] ?? message['timestamp']).toString(),
        'chatId': chatId,
        'senderId': message['senderId']?.toString(),
        'senderName': message['senderName']?.toString(),
        'text': message['text']?.toString() ?? '',
        'timestamp': message['timestamp'] is int ? message['timestamp'] : int.tryParse(message['timestamp']?.toString() ?? '0') ?? 0,
        'status': message['status'] ?? 'sent',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLocalMessages(String chatId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> saveLocalChat(Map<String, dynamic> chat) async {
    final db = await database;
    await db.insert(
      'chats',
      {
        'id': chat['id']?.toString(),
        'user1Id': chat['user1Id']?.toString(),
        'user2Id': chat['user2Id']?.toString(),
        'user1Name': chat['user1Name']?.toString(),
        'user2Name': chat['user2Name']?.toString(),
        'lastMessage': chat['lastMessage']?.toString(),
        'lastMessageTime': chat['lastMessageTime'] is int ? chat['lastMessageTime'] : int.tryParse(chat['lastMessageTime']?.toString() ?? '0') ?? 0,
        'created_at': chat['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLocalChats(String userId) async {
    final db = await database;
    return await db.query(
      'chats',
      where: 'user1Id = ? OR user2Id = ?',
      whereArgs: [userId, userId],
      orderBy: 'lastMessageTime DESC',
    );
  }

  Future<void> updateLocalChatLastMessage(String chatId, String lastMessage, int lastMessageTime) async {
    final db = await database;
    await db.update(
      'chats',
      {
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
      },
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }
}