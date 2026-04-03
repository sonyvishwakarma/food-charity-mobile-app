const db = require('../database/db');
const { v4: uuidv4 } = require('uuid');
const asyncHandler = require('express-async-handler');

class TaskController {
  assignTask = asyncHandler(async (req, res) => {
    const { donationId, requestId, volunteerId } = req.body;

    if (!donationId && !requestId) {
      return res.status(400).json({
        success: false,
        message: 'Either Donation ID or Request ID is required'
      });
    }

    if (!volunteerId) {
      return res.status(400).json({
        success: false,
        message: 'Volunteer ID is required'
      });
    }

    const database = db.getDb();
    
    // Validate donation if provided
    if (donationId) {
      const donation = await database.get('SELECT status FROM donations WHERE id = ?', [donationId]);
      if (!donation || donation.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: 'Donation is not available'
        });
      }
    }

    // Validate request if provided
    if (requestId) {
      const request = await database.get('SELECT status FROM food_requests WHERE id = ?', [requestId]);
      if (!request || request.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: 'Request is not available'
        });
      }
    }

    const taskId = `task_${uuidv4().substring(0, 8)}`;
    const now = new Date().toISOString();

    // Start transaction
    await database.run('BEGIN TRANSACTION');

    try {
      // Create task
      await database.run(
        `INSERT INTO delivery_tasks (
          id, donationId, requestId, volunteerId, status, assignedAt
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [taskId, donationId || null, requestId || null, volunteerId, 'assigned', now]
      );

      // Update donation status if provided
      if (donationId) {
        await database.run('UPDATE donations SET status = "assigned" WHERE id = ?', [donationId]);
      }

      // If there's a specific request, update its status too
      if (requestId) {
        let donorIdToLink = null;
        if (donationId) {
          const donation = await database.get('SELECT donorId FROM donations WHERE id = ?', [donationId]);
          donorIdToLink = donation ? donation.donorId : null;
        }
        await database.run(
          'UPDATE food_requests SET status = "assigned", donorId = ? WHERE id = ?', 
          [donorIdToLink, requestId]
        );
      }

      await database.run('COMMIT');

      res.status(201).json({
        success: true,
        message: 'Task assigned successfully',
        taskId
      });

    } catch (err) {
      await database.run('ROLLBACK');
      throw err;
    }
  });

  getVolunteerTasks = asyncHandler(async (req, res) => {
    const { volunteerId } = req.params;
    const database = db.getDb();

    const tasks = await database.all(
      `SELECT t.*, 
              COALESCE(d.foodType, r.foodType) as foodType,
              COALESCE(d.quantity, r.numberOfPeople || ' servings') as quantity,
              COALESCE(d.pickupAddress, r.address, 'N/A') as location,
              COALESCE(d.pickupAddress, 'N/A') as pickupAddress,
              COALESCE(d.pickupDate, r.createdAt) as date,
              COALESCE(d.pickupTime, 'ASAP') as time,
              d.latitude as donorLat, d.longitude as donorLng,
              r.address as recipientAddress, r.latitude as recipientLat, r.longitude as recipientLng,
              dr.phone as donorContact, dr.name as donorName, dr.id as donorId,
              rc.phone as recipientContact, rc.name as recipientName, rc.id as recipientId
       FROM delivery_tasks t
       LEFT JOIN donations d ON t.donationId = d.id
       LEFT JOIN users dr ON d.donorId = dr.id
       LEFT JOIN food_requests r ON t.requestId = r.id
       LEFT JOIN users rc ON r.recipientId = rc.id
       WHERE t.volunteerId = ?
       ORDER BY t.assignedAt DESC`,
      [volunteerId]
    );

    res.status(200).json({
      success: true,
      tasks
    });
  });

  updateTaskStatus = asyncHandler(async (req, res) => {
    const { taskId, status } = req.body;
    const database = db.getDb();

    if (!taskId || !status) {
      return res.status(400).json({ success: false, message: 'Task ID and Status are required' });
    }

    const task = await database.get('SELECT * FROM delivery_tasks WHERE id = ?', [taskId]);
    
    if (!task) {
      return res.status(404).json({ success: false, message: 'Task not found' });
    }

    const now = new Date().toISOString();
    let updateTaskQuery = 'UPDATE delivery_tasks SET status = ?';
    let updateDonationQuery = 'UPDATE donations SET status = ? WHERE id = ?';
    let params = [status];

    if (status === 'picked_up') {
      updateTaskQuery += ', pickedUpAt = ?';
      params.push(now);
    } else if (status === 'delivered' || status === 'completed') {
      updateTaskQuery += ', deliveredAt = ?';
      params.push(now);
    }
    
    updateTaskQuery += ' WHERE id = ?';
    params.push(taskId);

    await database.run('BEGIN TRANSACTION');
    try {
      await database.run(updateTaskQuery, params);
      
      // Update donation status if linked
      if (task.donationId) {
        const donationStatus = status === 'delivered' ? 'completed' : status;
        await database.run(updateDonationQuery, [donationStatus, task.donationId]);
      }
      
      // Update request status if linked
      if (task.requestId && (status === 'delivered' || status === 'completed')) {
        await database.run(
          'UPDATE food_requests SET status = "completed" WHERE id = ?',
          [task.requestId]
        );
      }
      await database.run('COMMIT');
      
      res.status(200).json({ 
        success: true, 
        message: `Task status updated to ${status} successfully` 
      });
    } catch (err) {
      await database.run('ROLLBACK');
      throw err;
    }
  });

  getVolunteerStats = asyncHandler(async (req, res) => {
    const { volunteerId } = req.params;
    const database = db.getDb();

    const stats = await database.get(
      `SELECT 
        COUNT(*) as totalTasks,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END) as deliveries,
        COUNT(CASE WHEN status = 'assigned' OR status = 'picked_up' THEN 1 END) as activeTasks
       FROM delivery_tasks WHERE volunteerId = ?`,
      [volunteerId]
    );

    // Sum up quantity from donations OR servings from requests for completed tasks
    const statsResult = await database.get(
      `SELECT 
        SUM(CASE 
          WHEN t.donationId IS NOT NULL THEN CAST(d.quantity AS FLOAT)
          WHEN t.requestId IS NOT NULL THEN CAST(fr.numberOfPeople AS FLOAT) / 4.0
          ELSE 0 
        END) as totalQuantity
       FROM delivery_tasks t
       LEFT JOIN donations d ON t.donationId = d.id
       LEFT JOIN food_requests fr ON t.requestId = fr.id
       WHERE t.volunteerId = ? AND (t.status = 'delivered' OR t.status = 'completed')`,
      [volunteerId]
    );

    const totalQuantity = statsResult.totalQuantity || 0;

    res.status(200).json({
      success: true,
      stats: {
        deliveries: stats.deliveries || 0,
        activeTasks: stats.activeTasks || 0,
        meals: Math.round(totalQuantity * 4),
        hours: Math.round((stats.deliveries || 0) * 1.5) // Estimate 1.5 hours per delivery
      }
    });
  });
}

module.exports = new TaskController();
