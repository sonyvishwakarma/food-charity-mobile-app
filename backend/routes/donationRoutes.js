const express = require('express');
const router = express.Router();
const donationController = require('../controllers/donationController');
const auth = require('../middleware/auth');
const authorize = require('../middleware/roleMiddleware');
const { validate, schemas } = require('../middleware/validator');
const upload = require('../middleware/upload');

// TEMP DEBUG ROUTES

router.get('/debug/users', async (req, res) => {
  const db = require('../database/db');

  const users = await db.all(
    'SELECT * FROM users'
  );

  res.json({
    success: true,
    users
  });
});


router.get('/debug/donations', async (req, res) => {
  const db = require('../database/db');

  const donations = await db.all(
    'SELECT * FROM donations'
  );

  res.json({
    success: true,
    donations
  });
});


router.get('/debug/requests', async (req, res) => {
  const db = require('../database/db');

  const requests = await db.all(
    'SELECT * FROM food_requests'
  );

  res.json({
    success: true,
    requests
  });
});


router.get('/debug/chats', async (req, res) => {
  const db = require('../database/db');

  const chats = await db.all(
    'SELECT * FROM chats'
  );

  res.json({
    success: true,
    chats
  });
});


router.get('/debug/messages', async (req, res) => {
  const db = require('../database/db');

  const messages = await db.all(
    'SELECT * FROM messages'
  );

  res.json({
    success: true,
    messages
  });
});


// Only donors can create donations - adding image upload support
router.post(
  '/', 
  auth, 
  authorize('donor'), 
  upload.single('image'), // Handle image upload
  validate(schemas.donation.create), 
  donationController.createDonation.bind(donationController)
);

router.get(
  '/',
  auth,
  authorize(['donor', 'volunteer', 'admin']),
  donationController.getAvailableDonations.bind(donationController)
);

router.get('/debug/donations', async (req, res) => {
  const db = require('../database/db');

  const donations = await db.all(
    'SELECT * FROM donations ORDER BY createdAt DESC'
  );

  res.json({
    success: true,
    count: donations.length,
    donations
  });
});
// Donors can see their own history, admins can see all
router.get('/donor/:donorId', auth, authorize(['donor', 'admin']), donationController.getDonorDonations.bind(donationController));

// Stats for donors
router.get('/stats/:donorId', auth, authorize(['donor', 'admin']), donationController.getDonorStats.bind(donationController));

// Volunteers and admins can see available donations to pick them up
router.get('/available', auth, authorize(['volunteer', 'admin']), donationController.getAvailableDonations.bind(donationController));

module.exports = router;


// for all api data
// TEMP DEBUG API - Remove after testing
router.get('/debug/all-data', async (req, res) => {
  const db = require('../database/db');

  try {
    const users = await db.all('SELECT * FROM users');
    const donations = await db.all('SELECT * FROM donations');
    const foodRequests = await db.all('SELECT * FROM food_requests');
    const deliveryTasks = await db.all('SELECT * FROM delivery_tasks');
    const chats = await db.all('SELECT * FROM chats');
    const messages = await db.all('SELECT * FROM messages');

    res.json({
      success: true,
      data: {
        users,
        donations,
        foodRequests,
        deliveryTasks,
        chats,
        messages
      }
    });

  } catch (error) {
    console.error(error);

    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});


module.exports = router;
