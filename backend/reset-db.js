const db = require('./database/db');

async function resetDatabase() {
  console.log('🗑️ Starting Database Reset...');
  
  try {
    const database = await db.connect();
    
    // List of tables to clear
    const tables = ['messages', 'chats', 'delivery_tasks', 'food_requests', 'donations', 'users'];
    
    console.log('⚠️ Deleting all records from tables...');
    
    for (const table of tables) {
      try {
        await database.exec(`DELETE FROM ${table}`);
        console.log(`✅ Cleared table: ${table}`);
      } catch (err) {
        console.log(`ℹ️ Skipping ${table}: ${err.message}`);
      }
    }
    
    console.log('\n✨ Database is now completely empty!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Reset failed:', error);
    process.exit(1);
  }
}

resetDatabase();
