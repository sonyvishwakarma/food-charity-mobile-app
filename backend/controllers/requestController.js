const db = require('../database/db');
const { v4: uuidv4 } = require('uuid');
const matchingService = require('../services/matchingService');

const asyncHandler = require('express-async-handler');

class RequestController {
  createRequest = asyncHandler(async (req, res) => {
    const {
      recipientId,
      foodType,
      category,
      quantityRequired,
      numberOfPeople,
      preferredDate,
      preferredTime,
      specialRequirements,
      contactNumber,
      isVeg,
      address,
      latitude,
      longitude
    } = req.body;

    if (!recipientId || !foodType) {
      return res.status(400).json({
        success: false,
        message: 'Recipient ID and Food Type are required'
      });
    }

    const database = db.getDb();
    const id = `req_${uuidv4().substring(0, 8)}`;
    const now = new Date().toISOString();

    await database.run(
      `INSERT INTO food_requests (
        id, recipientId, foodType, category, quantityRequired, numberOfPeople, 
        preferredDate, preferredTime, specialRequirements, isVeg, address, 
        contactNumber, latitude, longitude, status, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, recipientId, foodType, category || 'others', quantityRequired || '', numberOfPeople || 1, 
        preferredDate, preferredTime, specialRequirements,
        isVeg === 'true' || isVeg === true ? 1 : 0, address, contactNumber, latitude, longitude, 'pending', now
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Food request submitted successfully',
      requestId: id
    });
  });

  getRecipientRequests = asyncHandler(async (req, res) => {
    const { recipientId } = req.params;
    const database = db.getDb();
    
    const requests = await database.all(
      `SELECT r.*, t.volunteerId, u.name as volunteerName, u.phone as volunteerPhone
       FROM food_requests r
       LEFT JOIN delivery_tasks t ON r.id = t.requestId
       LEFT JOIN users u ON t.volunteerId = u.id
       WHERE r.recipientId = ? 
       ORDER BY r.createdAt DESC`,
      [recipientId]
    );

    res.status(200).json({
      success: true,
      requests: requests.map(r => ({
        ...r,
        isVeg: r.isVeg === 1
      }))
    });
  });

  getAvailableRequests = asyncHandler(async (req, res) => {
    const database = db.getDb();
    const requests = await database.all(
      `SELECT fr.*, u.name as recipientName 
       FROM food_requests fr 
       JOIN users u ON fr.recipientId = u.id 
       WHERE fr.status = "pending" 
       ORDER BY fr.createdAt DESC`
    );

    res.status(200).json({
      success: true,
      requests: requests.map(r => ({
        ...r,
        isVeg: r.isVeg === 1
      }))
    });
  });

  getRecipientStats = asyncHandler(async (req, res) => {
    const { recipientId } = req.params;
    const database = db.getDb();

    const stats = await database.get(
      `SELECT 
        COUNT(*) as totalRequests,
        COUNT(CASE WHEN status = 'completed' THEN 1 END) as completedRequests,
        COUNT(CASE WHEN status = 'pending' OR status = 'assigned' THEN 1 END) as activeRequests
       FROM food_requests WHERE recipientId = ?`,
      [recipientId]
    );

    // Estimate meals based on servings requested for completed requests
    const servingsResult = await database.get(
      `SELECT SUM(CAST(numberOfPeople AS INTEGER)) as totalServings
       FROM food_requests 
       WHERE recipientId = ? AND status = 'completed'`,
      [recipientId]
    );

    res.status(200).json({
      success: true,
      stats: {
        mealsReceived: servingsResult.totalServings || 0,
        peopleFed: servingsResult.totalServings || 0,
        activeRequests: stats.activeRequests || 0,
        upcoming: stats.activeRequests || 0
      }
    });
  });
  updateRequestStatus = asyncHandler(async (req, res) => {
    const { requestId, status, donorId } = req.body;

    if (!requestId || !status) {
      return res.status(400).json({ success: false, message: 'requestId and status are required' });
    }

    const allowedStatuses = ['accepted', 'declined', 'pending', 'completed', 'assigned'];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const database = db.getDb();

    const updateFields = ['status = ?'];
    const values = [status];

    if (donorId) {
      updateFields.push('donorId = ?');
      values.push(donorId);
    }

    values.push(requestId);

    await database.run(
      `UPDATE food_requests SET ${updateFields.join(', ')} WHERE id = ?`,
      values
    );

    res.status(200).json({ success: true, message: `Request ${status} successfully` });
  });
}

module.exports = new RequestController();
