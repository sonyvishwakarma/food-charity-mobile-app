require('dotenv').config();
const { Pool } = require('pg');

async function initNeon() {
  const connectionString = process.env.DATABASE_URL;
  
  if (!connectionString) {
    console.error('❌ Error: DATABASE_URL is not set in backend/.env');
    console.log('Please add your Neon connection string to backend/.env first.');
    return;
  }

  console.log('🌐 Connecting to Neon PostgreSQL...');
  const pool = new Pool({
    connectionString: connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    const client = await pool.connect();
    console.log('✅ Connected successfully!');
    
    console.log('🏗️ Creating tables...');
    const queries = [
      `CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        phone TEXT UNIQUE,
        role TEXT NOT NULL,
        password TEXT,
        status TEXT DEFAULT 'active',
        verified INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        lastLogin TEXT,
        additionalInfo TEXT
      )`,
      `CREATE TABLE IF NOT EXISTS donations (
        id TEXT PRIMARY KEY,
        donorId TEXT NOT NULL,
        foodType TEXT NOT NULL,
        quantity TEXT,
        servings TEXT,
        description TEXT,
        isVeg INTEGER,
        imageUrl TEXT,
        pickupAddress TEXT,
        pickupDate TEXT,
        pickupTime TEXT,
        latitude REAL,
        longitude REAL,
        status TEXT DEFAULT 'pending',
        createdAt TEXT NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS food_requests (
        id TEXT PRIMARY KEY,
        recipientId TEXT NOT NULL,
        foodType TEXT NOT NULL,
        quantityRequired TEXT,
        servingsRequired TEXT,
        description TEXT,
        address TEXT,
        status TEXT DEFAULT 'pending',
        donorId TEXT,
        createdAt TEXT NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS delivery_tasks (
        id TEXT PRIMARY KEY,
        donationId TEXT,
        requestId TEXT,
        volunteerId TEXT NOT NULL,
        status TEXT DEFAULT 'assigned',
        assignedAt TEXT NOT NULL,
        pickedUpAt TEXT,
        deliveredAt TEXT
      )`,
      `CREATE TABLE IF NOT EXISTS chats (
        id TEXT PRIMARY KEY,
        user1Id TEXT NOT NULL,
        user2Id TEXT NOT NULL,
        user1Name TEXT,
        user2Name TEXT,
        lastMessage TEXT,
        lastMessageTime BIGINT,
        createdAt TEXT NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderName TEXT,
        text TEXT,
        timestamp BIGINT NOT NULL,
        read INTEGER DEFAULT 0
      )`
    ];

    for (const q of queries) {
      await client.query(q);
    }
    
    console.log('✅ All tables created successfully in Neon!');
    client.release();
  } catch (err) {
    console.error('❌ Error during initialization:', err);
  } finally {
    await pool.end();
  }
}

initNeon();
