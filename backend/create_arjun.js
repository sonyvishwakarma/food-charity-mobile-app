const db = require('./database/db');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

async function createArjunAdmin() {
  try {
    await db.connect();
    const database = db.getDb();
    
    // Check if user exists
    const existing = await database.get(
      'SELECT id FROM users WHERE email = ?',
      ['arjun09@gmail.com']
    );

    if (existing) {
      await database.run('DELETE FROM users WHERE email = ?', ['arjun09@gmail.com']);
      console.log('🧹 Existing arjun09 user cleared');
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('arjun09', salt);
    const id = uuidv4();
    const now = new Date().toISOString();

    await database.run(
      `INSERT INTO users (id, name, email, phone, password, role, verified, createdAt, additionalInfo)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)`,
      [id, 'Arjun Admin', 'arjun09@gmail.com', '9876543210', hashedPassword, 'admin', now, JSON.stringify({})]
    );

    console.log('✅ Admin user "arjun09@gmail.com" created successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating admin user:', error);
    process.exit(1);
  }
}

createArjunAdmin();
