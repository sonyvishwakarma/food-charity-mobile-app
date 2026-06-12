const db = require('../database/db');
const { v4: uuidv4 } = require('uuid');
const matchingService = require('../services/matchingService');

const asyncHandler = require('express-async-handler');

class DonationController {
  createDonation = asyncHandler(async (req, res) => {
    const {
      donorId,
      foodType,
      category,
      quantity,
      servings,
      description,
      isVeg,
      pickupAddress,
      pickupDate,
      pickupTime,
      specialInstructions,
      contactNumber,
      hasAllergens,
      allergens,
      latitude,
      longitude
    } = req.body;

    if (!donorId || !foodType) {
      return res.status(400).json({
        success: false,
        message: 'Donor ID and Food Type are required'
      });
    }
console.log("📥 Donation Request Body:", req.body);
    // Get image URL if uploaded
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const database = db.getDb();
    const id = `don_${uuidv4().substring(0, 8)}`;
    const now = new Date().toISOString();

// to check if data is stored properly or not on console itself
console.log("💾 Inserting donation into SQLite:", {
  id,
  donorId,
  foodType,
  quantity
});

    const result = await database.run(
      `INSERT INTO donations (
        id, donorId, foodType, category, quantity, servings, description, isVeg, 
        imageUrl, pickupAddress, pickupDate, pickupTime, specialInstructions, 
        contactNumber, hasAllergens, allergens, latitude, longitude, status, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, donorId, foodType, category || 'others', quantity, servings, description, 
        isVeg === 'true' || isVeg === true ? 1 : 0,
        imageUrl,
        pickupAddress, pickupDate, pickupTime, specialInstructions, contactNumber,
        hasAllergens === 'true' || hasAllergens === true ? 1 : 0, 
        Array.isArray(allergens) ? JSON.stringify(allergens) : (allergens || '[]'), 
        parseFloat(latitude), parseFloat(longitude),
        'pending', now
      ]
    );
    console.log("SQLIter Insert Result : ", result)


    const matches = await matchingService.findMatchesForDonation(id);
    console.log(`🔍 Found ${matches.length} matches for new donation ${id}`);

    res.status(201).json({
      success: true,
      message: 'Donation submitted successfully',
      donationId: id,
      imageUrl: imageUrl,
      potentialMatches: matches
    });
  });

  getDonorDonations = asyncHandler(async (req, res) => {
    const { donorId } = req.params;
    const database = db.getDb();
    
    const donations = await database.all(
      `SELECT d.*, t.volunteerId, u.name as volunteerName, u.phone as volunteerPhone
       FROM donations d
       LEFT JOIN delivery_tasks t ON d.id = t.donationId
       LEFT JOIN users u ON t.volunteerId = u.id
       WHERE d.donorId = ? 
       ORDER BY d.createdAt DESC`,
      [donorId]
    );

    res.status(200).json({
      success: true,
      donations: donations.map(d => ({
        ...d,
        isVeg: d.isVeg === 1,
        hasAllergens: d.hasAllergens === 1,
        allergens: JSON.parse(d.allergens || '[]')
      }))
    });
  });

  getAvailableDonations = asyncHandler(async (req, res) => {
    const database = db.getDb();
    // Returns pending donations that haven't been assigned to a task yet
    const donations = await database.all(
      'SELECT * FROM donations WHERE status = "pending" ORDER BY createdAt DESC'
    );

    res.status(200).json({
      success: true,
      donations: donations.map(d => ({
        ...d,
        isVeg: d.isVeg === 1,
        hasAllergens: d.hasAllergens === 1,
        allergens: JSON.parse(d.allergens || '[]')
      }))
    });
  });

  getDonorStats = asyncHandler(async (req, res) => {
    const { donorId } = req.params;
    console.log(`📊 Fetching stats for donor: ${donorId}`);
    const database = db.getDb();
    
    const stats = await database.get(
      `SELECT 
        COUNT(*) as totalDonations, 
        SUM(CAST(quantity AS FLOAT)) as totalQuantity,
        COUNT(CASE WHEN status = 'pending' OR status = 'assigned' OR status = 'picked_up' THEN 1 END) as activeDonations
       FROM donations WHERE donorId = ?`,
      [donorId]
    );

    console.log('📈 DB Stats Result:', stats);

    const totalQuantity = stats.totalQuantity || 0;
    
    res.status(200).json({
      success: true,
      stats: {
        totalDonations: stats.totalDonations || 0,
        totalQuantity: totalQuantity,
        activeDonations: stats.activeDonations || 0,
        peopleFed: Math.round(totalQuantity * 4) // Rough estimate: 250g per person
      }
    });
  });
}

module.exports = new DonationController();
