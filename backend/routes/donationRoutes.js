const express = require('express');
const router = express.Router();
const donationController = require('../controllers/donationController');
const auth = require('../middleware/auth');
const authorize = require('../middleware/roleMiddleware');
const { validate, schemas } = require('../middleware/validator');
const upload = require('../middleware/upload');

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
