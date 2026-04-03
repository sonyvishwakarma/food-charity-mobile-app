const db = require('./database/db');

async function migrate() {
  try {
    const database = await db.connect();
    
    console.log('Dropping donations table...');
    await database.exec('DROP TABLE IF EXISTS donations');
    
    console.log('Dropping food_requests table...');
    await database.exec('DROP TABLE IF EXISTS food_requests');
    
    console.log('Recreating tables...');
    await database.createTables();
    
    console.log('Done!');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

migrate();
