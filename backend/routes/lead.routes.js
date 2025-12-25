const express = require('express');
const rateLimit = require('express-rate-limit');
const csurf = require('csurf');
const redisClient = require('../config/redis');

const router = express.Router();

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  standardHeaders: true,
  legacyHeaders: false,
});

const csrfProtection = csurf({
  cookie: {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production'
  }
});

function isValidEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
  return re.test(String(email).toLowerCase());
}

router.post('/', limiter, csrfProtection, async (req, res) => {
  try {
    const email = String((req.body?.email || '').trim());
    if (!email || !isValidEmail(email) || email.length > 254) {
      return res.status(400).json({ success: false, message: 'Geçersiz e-posta' });
    }

    const lead = {
      email,
      ts: new Date().toISOString(),
      ip: req.ip,
      ua: req.headers['user-agent'] || ''
    };

    try {
      if (redisClient?.isConnected?.()) {
        await redisClient.lPush('leads', JSON.stringify(lead));
      }
    } catch (err) {
      console.warn('Lead Redis yazımı başarısız:', err.message);
    }

    return res.status(200).json({ success: true, message: 'Kaydınız alındı' });
  } catch (err) {
    console.error('Lead işleme hatası:', err);
    return res.status(500).json({ success: false, message: 'Sunucu hatası' });
  }
});

module.exports = router;
