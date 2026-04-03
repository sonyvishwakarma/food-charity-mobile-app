const db = require('../database/db');
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

class AuthController {

  async register(req, res) {
    try {
      let { name, email, phoneNumber, phone, role, password, additionalInfo } = req.body;
      phoneNumber = phoneNumber || phone;

      if (!name || (!email && !phoneNumber) || !role || !password) {
        return res.status(400).json({
          success: false,
          message: 'All fields are required'
        });
      }

      if (additionalInfo && typeof additionalInfo === 'object') {
        additionalInfo = JSON.stringify(additionalInfo);
      }

      const database = db.getDb();
      let user = null;

      if (phoneNumber && email) {
        user = await database.get(
          'SELECT * FROM users WHERE phone = ? OR email = ?',
          [phoneNumber, email]
        );
      } else if (phoneNumber) {
        user = await database.get(
          'SELECT * FROM users WHERE phone = ?',
          [phoneNumber]
        );
      } else {
        user = await database.get(
          'SELECT * FROM users WHERE email = ?',
          [email]
        );
      }

      if (user) {
        return res.status(400).json({
          success: false,
          message: 'User already exists'
        });
      }

      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      const newUser = new User({
        name: name || 'User',
        email: email || '',
        phone: phoneNumber || '',
        role: role || 'donor',
        password: hashedPassword,
        verified: 1,
        additionalInfo: additionalInfo
      });

      const userData = newUser.toDB();

      await database.run(
        `INSERT INTO users 
        (id, name, email, phone, password, role, verified, createdAt, additionalInfo)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          userData.id,
          userData.name,
          userData.email,
          userData.phone,
          userData.password,
          userData.role,
          userData.verified,
          userData.createdAt,
          userData.additionalInfo
        ]
      );

      const savedUser = await database.get(
        'SELECT * FROM users WHERE id = ?',
        [userData.id]
      );

      const userToReturn = User.fromDB(savedUser);

      const token = jwt.sign(
        {
          id: savedUser.id,
          role: savedUser.role,
          email: savedUser.email,
          tokenVersion: savedUser.tokenVersion || 1
        },
        process.env.JWT_SECRET || 'fallback_secret',
        { expiresIn: process.env.JWT_EXPIRES_IN || '30d' }
      );

      res.status(201).json({
        success: true,
        message: 'Registration successful',
        user: userToReturn,
        token: token
      });

    } catch (error) {
      console.error('❌ Register error:', error);
      res.status(500).json({
        success: false,
        message: 'Registration failed',
        error: error.message
      });
    }
  }

  async login(req, res) {
    try {
      const { email, phone, password } = req.body;

      if ((!email && !phone) || !password) {
        return res.status(400).json({
          success: false,
          message: 'Email/Phone and password are required'
        });
      }

      const database = db.getDb();
      let user = null;

      if (email) {
        user = await database.get(
          'SELECT * FROM users WHERE email = ?',
          [email]
        );
      } else {
        user = await database.get(
          'SELECT * FROM users WHERE phone = ?',
          [phone]
        );
      }

      console.log(`🔍 Checking user ${email ? 'email: ' + email : 'phone: ' + phone}`);
      if (!user) {
        console.log(`❌ USER NOT FOUND: ${email || phone}`);
        return res.status(401).json({
          success: false,
          message: 'User does not exist, please register'
        });
      }
      console.log(`✅ User found: ${user.name} (${user.id})`);

      let isMatch = false;

      if (user.password) {
        if (user.password.startsWith('$2a$') || user.password.startsWith('$2b$')) {
          isMatch = await bcrypt.compare(password, user.password);
        } else {
          isMatch = password === user.password;
        }
      }

      if (!isMatch) {
        return res.status(401).json({
          success: false,
          message: 'Invalid credentials'
        });
      }

      await database.run(
        'UPDATE users SET lastLogin = ? WHERE id = ?',
        [new Date().toISOString(), user.id]
      );

      const userData = User.fromDB(user);

      const token = jwt.sign(
        {
          id: user.id,
          role: user.role,
          email: user.email,
          tokenVersion: user.tokenVersion || 1
        },
        process.env.JWT_SECRET || 'fallback_secret',
        { expiresIn: process.env.JWT_EXPIRES_IN || '30d' }
      );

      res.status(200).json({
        success: true,
        message: 'Login successful',
        user: userData,
        token: token
      });

    } catch (error) {
      console.error('❌ Login error:', error);
      res.status(500).json({
        success: false,
        message: 'Login failed',
        error: error.message
      });
    }
  }

  async logout(req, res) {
    res.status(200).json({
      success: true,
      message: 'Logged out successfully'
    });
  }

  async changePassword(req, res) {
    try {
      const { currentPassword, newPassword } = req.body;
      const userId = req.user.id;

      const database = db.getDb();
      const user = await database.get(
        'SELECT * FROM users WHERE id = ?',
        [userId]
      );

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      let isMatch = false;

      if (user.password) {
        if (user.password.startsWith('$2a$') || user.password.startsWith('$2b$')) {
          isMatch = await bcrypt.compare(currentPassword, user.password);
        } else {
          isMatch = currentPassword === user.password;
        }
      }

      if (!isMatch) {
        return res.status(401).json({
          success: false,
          message: 'Incorrect current password'
        });
      }

      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(newPassword, salt);

      await database.run(
        'UPDATE users SET password = ? WHERE id = ?',
        [hashedPassword, userId]
      );

      res.status(200).json({
        success: true,
        message: 'Password changed successfully'
      });

    } catch (error) {
      console.error('❌ Change password error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to change password',
        error: error.message
      });
    }
  }

  async removeActiveSessions(req, res) {
    try {
      const userId = req.user.id;
      const database = db.getDb();

      await database.run(
        'UPDATE users SET tokenVersion = tokenVersion + 1 WHERE id = ?',
        [userId]
      );

      const user = await database.get(
        'SELECT * FROM users WHERE id = ?',
        [userId]
      );

      const newToken = jwt.sign(
        {
          id: user.id,
          role: user.role,
          email: user.email,
          tokenVersion: user.tokenVersion
        },
        process.env.JWT_SECRET || 'fallback_secret',
        { expiresIn: process.env.JWT_EXPIRES_IN || '30d' }
      );

      res.status(200).json({
        success: true,
        message: 'All other sessions have been logged out',
        token: newToken
      });

    } catch (error) {
      console.error('❌ Remove sessions error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to remove sessions'
      });
    }
  }

  async exportData(req, res) {
    try {
      const userId = req.user.id;
      const database = db.getDb();

      const user = await database.get(
        'SELECT * FROM users WHERE id = ?',
        [userId]
      );

      const donations = await database.all(
        'SELECT * FROM donations WHERE donorId = ?',
        [userId]
      );

      const requests = await database.all(
        'SELECT * FROM food_requests WHERE recipientId = ?',
        [userId]
      );

      const tasks = await database.all(
        'SELECT * FROM delivery_tasks WHERE volunteerId = ?',
        [userId]
      );

      const exportData = {
        profile: User.fromDB(user),
        donations,
        foodRequests: requests,
        deliveryTasks: tasks,
        exportedAt: new Date().toISOString()
      };

      res.status(200).json({
        success: true,
        data: exportData
      });

    } catch (error) {
      console.error('❌ Export error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to export data'
      });
    }
  }

  async getAllUsers(req, res) {
    try {
      const database = db.getDb();

      const users = await database.all(
        'SELECT id, name, email, phone, role, verified, createdAt, lastLogin FROM users ORDER BY createdAt DESC'
      );

      res.status(200).json({
        success: true,
        count: users.length,
        users: users.map(user => User.fromDB(user))
      });

    } catch (error) {
      console.error('❌ Get users error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get users',
        error: error.message
      });
    }
  }

  async forgotPassword(req, res) {
    try {
      const { email, phoneNumber } = req.body;
      const database = db.getDb();
      let user = null;

      if (email) {
        user = await database.get(
          'SELECT * FROM users WHERE email = ?',
          [email]
        );
      } else if (phoneNumber) {
        user = await database.get(
          'SELECT * FROM users WHERE phone = ?',
          [phoneNumber]
        );
      }

      if (!user) {
        return res.status(404).json({
          success: false,
          message: 'User with this email/phone not found'
        });
      }

      res.status(200).json({
        success: true,
        message: 'Password reset link sent successfully'
      });

    } catch (error) {
      console.error('❌ Forgot password error:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to process forgot password request',
        error: error.message
      });
    }
  }
}

module.exports = new AuthController();