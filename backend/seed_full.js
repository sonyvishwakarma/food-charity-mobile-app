const db = require('./database/db');
const { v4: uuidv4 } = require('uuid');

async function seedData() {
  try {
    const database = await db.connect();
    console.log('Inserting dummy data...');
    
    // Create a donor and a recipient if they don't exist
    const donorId = uuidv4();
    const recipientId = uuidv4();
    const now = new Date().toISOString();
    
    await database.run(
      `INSERT INTO users (id, name, email, phone, role, password, status, verified, createdAt, additionalInfo) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [donorId, 'Dummy Donor', 'dummy.donor@test.com', '1111111111', 'donor', 'hash', 'active', 1, now, '{}']
    );

    await database.run(
      `INSERT INTO users (id, name, email, phone, role, password, status, verified, createdAt, additionalInfo) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [recipientId, 'Dummy Recipient', 'dummy.recipient@test.com', '2222222222', 'recipient', 'hash', 'active', 1, now, '{"recipientType": "orphanage"}']
    );
    
    // Add a donation
    const donationId = `don_${uuidv4().substring(0, 8)}`;
    await database.run(
      `INSERT INTO donations (id, donorId, foodType, category, quantity, servings, description, isVeg, pickupAddress, latitude, longitude, status, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [donationId, donorId, 'Rice and Curry', 'cooked', '2 kg', '10', 'Freshly cooked rice and curry', 1, '123 Donor St', 12.9716, 77.5946, 'pending', now]
    );
    
    // Add a food request
    const requestId = `req_${uuidv4().substring(0, 8)}`;
    await database.run(
      `INSERT INTO food_requests (id, recipientId, foodType, category, quantityRequired, servingsRequired, description, isVeg, address, latitude, longitude, status, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [requestId, recipientId, 'Rice and Curry', 'cooked', '2 kg', '10', 'Need lunch for orphanage', 1, '456 Recipient Ave', 12.9720, 77.5950, 'pending', now]
    );

    console.log('Dummy data inserted successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Error inserting dummy data:', err);
    process.exit(1);
  }
}

seedData();
