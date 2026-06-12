require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const hpp = require('hpp');
const fs = require('fs');

// Import database
const db = require('./database/db');

// Import routes
const authRoutes = require('./routes/authRoutes');
const donationRoutes = require('./routes/donationRoutes');
const requestRoutes = require('./routes/requestRoutes');
const taskRoutes = require('./routes/taskRoutes');
const adminRoutes = require('./routes/adminRoutes');
const chatRoutes = require('./routes/chatRoutes');

const app = express();
const PORT = process.env.PORT || 4000;

// Security Middlewares
app.use(helmet({
  crossOriginResourcePolicy: false, // Allow images to be loaded by different origins (Flutter)
  contentSecurityPolicy: false, // Disable CSP to allow Flutter Web to load assets/APIs
}));
app.use(hpp()); // Prevent HTTP Parameter Pollution

// Rate Limiting - Increased for Chat Polling
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 2000, // Increased from 100 to 2000 to handle chat polling
  message: {
    success: false,
    message: 'Too many requests, please try again later'
  }
});
app.use('/api/', limiter);

// Logging
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Global Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files for uploads
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
app.use('/uploads', express.static(uploadDir));

// Request logging (custom message if needed)
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  
  if (req.method === 'POST' && req.url.includes('donations')) {
    try {
      const fs = require('fs');
      const logMsg = `[${new Date().toISOString()}] ${req.method} ${req.url}\nBody: ${JSON.stringify(req.body)}\nHeaders: ${JSON.stringify(req.headers)}\n\n`;
      fs.appendFileSync(path.join(__dirname, 'donation_debug.log'), logMsg);
    } catch (e) {}
  }
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/donations', donationRoutes);
app.use('/api/food-requests', requestRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/chat', chatRoutes);

// Test route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Annadanam API - Production Ready with SQLite',
    database: db.db ? 'connected' : 'disconnected',
    environment: process.env.NODE_ENV || 'production',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err.stack);
  
  const isDev = process.env.NODE_ENV === 'development' || !process.env.NODE_ENV;
  
  // Extract file and line number from stack
  const stackLines = err.stack ? err.stack.split('\n') : [];
  const errorLocation = stackLines.length > 1 ? stackLines[1].trim() : 'unknown';

  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    error: isDev ? {
      message: err.message,
      location: errorLocation,
      stack: err.stack
    } : undefined
  });
});

// Start server
async function startServer() {
  try {
    await db.connect();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Annadanam Server Status:`);
      console.log(`- Local: http://localhost:${PORT}`);
      console.log(`- Web Test: http://localhost:${PORT}/`);
      console.log(`- Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`- Database path: ${path.join(__dirname, 'db', 'annadanam.sqlite')}`);
      console.log(`\n📱 TO TEST ON PHYSICAL PHONE:`);
      console.log(`1. Your phone and PC MUST be on the SAME WiFi.`);
      console.log(`2. Update .env file with your PC's actual WiFi IP.`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Global error handlers
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

startServer();