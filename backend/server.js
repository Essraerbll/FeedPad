const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
require('dotenv').config();

const app = express();

// Middleware
app.use(helmet());
app.use(cors({
  origin: true,
  credentials: true,
}));
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Routes
const authRoutes = require('./routes/auth.routes');
app.use('/api/auth', authRoutes);

const markerRoutes = require('./routes/marker.routes');
app.use('/api/markers', markerRoutes);

const postsRoutes = require('./routes/posts.routes');
app.use('/api/posts', postsRoutes);

// Diğer route'lar (varsa)
try {
  const locationRoutes = require('./routes/location.routes');
  app.use('/api/location', locationRoutes);
} catch (e) {
  // Route dosyası yoksa devam et
}

try {
  const userRoutes = require('./routes/user.routes');
  app.use('/api/user', userRoutes);
} catch (e) {
  // Route dosyası yoksa devam et
}

// Health check
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    message: 'FeedPad API is running',
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
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost'; // Localhost ve ağdan dinle

app.listen(PORT, HOST, () => {
  console.log(`🚀 Server is running on http://${HOST}:${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🌐 Local: http://localhost:${PORT}`);
  console.log(`📱 Network: http://192.168.1.108:${PORT}`);
});

module.exports = app;

