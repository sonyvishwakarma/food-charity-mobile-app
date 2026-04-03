const sqlite3 = require('sqlite3');
const { open } = require('sqlite');
const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');

class Database {
  constructor() {
    this.db = null; // SQLite instance
    this.pool = null; // PostgreSQL instance
    this.isPostgres = false;
  }

  async connect() {
    try {
      // 1. Check if we should use PostgreSQL (Render/Production)
      if (process.env.DATABASE_URL) {
        console.log('🌐 Connecting to PostgreSQL (Production Mode)...');
        this.pool = new Pool({
          connectionString: process.env.DATABASE_URL,
          ssl: { rejectUnauthorized: false } // Required for Neon/Render
        });
        this.isPostgres = true;
        
        // Test connection
        const client = await this.pool.connect();
        console.log('✅ PostgreSQL connected successfully');
        client.release();
      } 
      // 2. Fallback to SQLite (Local Development)
      else {
        console.log('📁 Connecting to Local SQLite (Development Mode)...');
        const dbDir = path.join(__dirname, '..', 'db');
        if (!fs.existsSync(dbDir)) fs.mkdirSync(dbDir, { recursive: true });

        this.db = await open({
          filename: path.join(dbDir, 'annadanam.sqlite'),
          driver: sqlite3.Database
        });
        console.log('✅ SQLite connected successfully');
      }

      await this.createTables();
      return this;
    } catch (error) {
      console.error('❌ Database connection error:', error);
      throw error;
    }
  }

  async run(query, params = []) {
    if (this.isPostgres) {
      // Map SQLite ? to Postgres $1, $2
      let pgQuery = query;
      params.forEach((_, i) => {
        pgQuery = pgQuery.replace('?', `$${i + 1}`);
      });
      return await this.pool.query(pgQuery, params);
    } else {
      return await this.db.run(query, params);
    }
  }

  async get(query, params = []) {
    if (this.isPostgres) {
      let pgQuery = query;
      params.forEach((_, i) => pgQuery = pgQuery.replace('?', `$${i + 1}`));
      const result = await this.pool.query(pgQuery, params);
      return result.rows[0];
    } else {
      return await this.db.get(query, params);
    }
  }

  async all(query, params = []) {
    if (this.isPostgres) {
      let pgQuery = query;
      params.forEach((_, i) => pgQuery = pgQuery.replace('?', `$${i + 1}`));
      const result = await this.pool.query(pgQuery, params);
      return result.rows;
    } else {
      return await this.db.all(query, params);
    }
  }

  async exec(query) {
    if (this.isPostgres) {
      return await this.pool.query(query);
    } else {
      return await this.db.exec(query);
    }
  }

  async createTables() {
    // Shared table creation logic
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
        category TEXT,
        quantity TEXT,
        servings TEXT,
        description TEXT,
        isVeg INTEGER,
        imageUrl TEXT,
        pickupAddress TEXT,
        pickupDate TEXT,
        pickupTime TEXT,
        specialInstructions TEXT,
        contactNumber TEXT,
        hasAllergens INTEGER,
        allergens TEXT,
        latitude REAL,
        longitude REAL,
        status TEXT DEFAULT 'pending',
        createdAt TEXT NOT NULL
      )`,
      `CREATE TABLE IF NOT EXISTS food_requests (
        id TEXT PRIMARY KEY,
        recipientId TEXT NOT NULL,
        foodType TEXT NOT NULL,
        category TEXT,
        quantityRequired TEXT,
        numberOfPeople INTEGER,
        preferredDate TEXT,
        preferredTime TEXT,
        specialRequirements TEXT,
        isVeg INTEGER,
        address TEXT,
        contactNumber TEXT,
        latitude REAL,
        longitude REAL,
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
        deliveredAt TEXT,
        pickupOtp TEXT,
        deliveryOtp TEXT
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
        text TEXT NOT NULL,
        timestamp BIGINT NOT NULL,
        read INTEGER DEFAULT 0
      )`
    ];

    for (const q of queries) {
      await this.exec(q);
    }
    console.log('✅ All database tables verified/created');
  }

  getDb() {
    return this; // For backward compatibility with controllers
  }
}

module.exports = new Database();