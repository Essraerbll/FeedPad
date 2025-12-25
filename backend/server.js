const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const compression = require('compression');
const csurf = require('csurf');
const path = require('path');
require('dotenv').config();

const app = express();

// Middleware
app.use(compression());
app.use(helmet());
// Strengthen CSP (inline scripts/styles disallowed)
app.use(helmet.contentSecurityPolicy({
  useDefaults: true,
  directives: {
    "default-src": ["'self'"],
    "img-src": ["'self'", "https:", "data:"],
    "script-src": ["'self'"],
    "style-src": ["'self'"],
    "font-src": ["'self'", "https:", "data:"],
    "connect-src": ["'self'"],
    "frame-ancestors": ["'none'"]
  }
}));
app.use(cors({
  origin: true,
  credentials: true,
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' })); // UTF-8 desteği için
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// Static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Serve promotional static site
app.use(express.static(path.join(__dirname, 'promo'), { etag: true, maxAge: '1d' }));

// CSRF protection (cookie-based)
const csrfProtection = csurf({
  cookie: {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production'
  }
});

// Endpoint to obtain CSRF token for forms
app.get('/csrf-token', csrfProtection, (req, res) => {
  res.json({ token: req.csrfToken() });
});

// Routes
const authRoutes = require('./routes/auth.routes');
app.use('/api/auth', authRoutes);

const markerRoutes = require('./routes/marker.routes');
app.use('/api/markers', markerRoutes);

const postsRoutes = require('./routes/posts.routes');
app.use('/api/posts', postsRoutes);

const messagingRoutes = require('./routes/messaging.routes');
app.use('/api/messaging', messagingRoutes);

// Lead capture (promo form)
try {
  const leadRoutes = require('./routes/lead.routes');
  app.use('/lead', leadRoutes);
} catch (e) {
  // Route dosyası yoksa devam et
}

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
// Tüm arayüzlerden dinleyelim; Android emülatörü (10.0.2.2) erişebilsin
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  const hostLabel = HOST === '0.0.0.0' ? '0.0.0.0 (all interfaces)' : HOST;
  console.log(`🚀 Server is running on http://${hostLabel}:${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🌐 Local: http://localhost:${PORT}`);
  console.log(`📱 Android emulator (host): http://10.0.2.2:${PORT}`);
});

module.exports = app;

