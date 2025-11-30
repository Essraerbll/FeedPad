const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const redisClient = require('../config/redis');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();

// Helper: Redis bağlantı kontrolü
function checkRedisConnection() {
  try {
    return redisClient && typeof redisClient.isConnected === 'function' && redisClient.isConnected();
  } catch (error) {
    return false;
  }
}

// Helper: Email ile kullanıcı bul
async function findUserByEmail(email) {
  try {
    if (!checkRedisConnection()) {
      console.error('Redis not connected');
      return null;
    }
    const userKey = `user:email:${email.toLowerCase()}`;
    const userId = await redisClient.get(userKey);
    if (!userId) return null;
    
    const userData = await redisClient.get(`user:${userId}`);
    return userData ? JSON.parse(userData) : null;
  } catch (error) {
    console.error('Error finding user by email:', error);
    return null;
  }
}

// Helper: Username ile kullanıcı bul
async function findUserByUsername(username) {
  try {
    if (!checkRedisConnection()) {
      console.error('Redis not connected');
      return null;
    }
    const usernameKey = `user:username:${username.toLowerCase()}`;
    const userId = await redisClient.get(usernameKey);
    if (!userId) return null;
    
    const userData = await redisClient.get(`user:${userId}`);
    return userData ? JSON.parse(userData) : null;
  } catch (error) {
    console.error('Error finding user by username:', error);
    return null;
  }
}

// Helper: Session kontrolü
async function verifySession(sessionId) {
  try {
    if (!checkRedisConnection()) {
      console.error('Redis not connected');
      return null;
    }
    const sessionData = await redisClient.get(`session:${sessionId}`);
    if (!sessionData) return null;
    
    const session = JSON.parse(sessionData);
    const userData = await redisClient.get(`user:${session.userId}`);
    return userData ? JSON.parse(userData) : null;
  } catch (error) {
    console.error('Error verifying session:', error);
    return null;
  }
}

// Kayıt ol endpoint
router.post('/register', [
  body('email').isEmail().withMessage('Geçersiz e-posta adresi'),
  body('password').isLength({ min: 6 }).withMessage('Şifre en az 6 karakter olmalı'),
  body('name').notEmpty().withMessage('İsim gereklidir'),
  body('username').optional().isLength({ min: 3 }).withMessage('Kullanıcı adı en az 3 karakter olmalı'),
  body('userType').isIn(['user', 'pet_shop_owner']).withMessage('Geçersiz kullanıcı tipi'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation hatası',
        errors: errors.array()
      });
    }

    const { email, password, name, username, userType } = req.body;

    // Email kontrolü
    const existingUserByEmail = await findUserByEmail(email);
    if (existingUserByEmail) {
      return res.status(400).json({
        success: false,
        message: 'Bu e-posta adresi zaten kullanımda.'
      });
    }

    // Username kontrolü (eğer verilmişse)
    if (username) {
      const existingUserByUsername = await findUserByUsername(username);
      if (existingUserByUsername) {
        return res.status(400).json({
          success: false,
          message: 'Bu kullanıcı adı zaten kullanılıyor.'
        });
      }
    }

    // Şifreyi hashle
    const hashedPassword = await bcrypt.hash(password, 10);

    // Kullanıcı ID oluştur
    const userId = uuidv4();

    // Kullanıcı verilerini Redis'e kaydet
    const userData = {
      id: userId,
      email: email.toLowerCase(),
      password: hashedPassword,
      name,
      username: username || '',
      userType,
      photoURL: '',
      isActive: true,
      createdAt: new Date().toISOString(),
      lastLogin: new Date().toISOString(),
    };

    // Redis'e kaydet
    await redisClient.set(`user:${userId}`, JSON.stringify(userData));
    await redisClient.set(`user:email:${email.toLowerCase()}`, userId);
    
    if (username) {
      await redisClient.set(`user:username:${username.toLowerCase()}`, userId);
    }

    res.status(201).json({
      success: true,
      message: 'Kayıt başarılı',
      user: {
        id: userData.id,
        email: userData.email,
        name: userData.name,
        username: userData.username,
        userType: userData.userType,
      }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({
      success: false,
      message: 'Kayıt sırasında bir hata oluştu'
    });
  }
});

// Giriş yap endpoint
router.post('/login', [
  body('email').isEmail().withMessage('Geçersiz e-posta adresi'),
  body('password').notEmpty().withMessage('Şifre gereklidir'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation hatası',
        errors: errors.array()
      });
    }

    const { email, password } = req.body;

    // Kullanıcıyı bul
    const user = await findUserByEmail(email);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Kullanıcı bulunamadı.'
      });
    }

    // Şifre kontrolü
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Hatalı şifre.'
      });
    }

    // Aktiflik kontrolü
    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Bu hesap devre dışı bırakılmış.'
      });
    }

    // Session oluştur
    const sessionId = uuidv4();
    const sessionData = {
      userId: user.id,
      email: user.email,
      createdAt: new Date().toISOString(),
    };

    // Session'ı Redis'e kaydet (24 saat geçerli)
    await redisClient.setEx(`session:${sessionId}`, 86400, JSON.stringify(sessionData));
    
    // Last login güncelle
    user.lastLogin = new Date().toISOString();
    await redisClient.set(`user:${user.id}`, JSON.stringify(user));

    // Cookie'ye session ID ekle
    res.cookie('sessionId', sessionId, {
      httpOnly: true,
      maxAge: 86400000, // 24 saat
      sameSite: 'lax',
    });

    res.json({
      success: true,
      message: 'Giriş başarılı',
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        username: user.username,
        userType: user.userType,
      },
      sessionId
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Giriş sırasında bir hata oluştu'
    });
  }
});

// Çıkış yap endpoint
router.post('/logout', async (req, res) => {
  try {
    const sessionId = req.cookies?.sessionId;
    
    if (sessionId) {
      await redisClient.del(`session:${sessionId}`);
    }

    res.clearCookie('sessionId');
    res.json({
      success: true,
      message: 'Çıkış başarılı'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'Çıkış sırasında bir hata oluştu'
    });
  }
});

// Mevcut kullanıcı bilgilerini getir
router.get('/me', async (req, res) => {
  try {
    const sessionId = req.cookies?.sessionId;
    
    if (!sessionId) {
      return res.status(401).json({
        success: false,
        message: 'Oturum bulunamadı'
      });
    }

    const user = await verifySession(sessionId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Geçersiz oturum'
      });
    }

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        username: user.username,
        userType: user.userType,
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      message: 'Kullanıcı bilgileri alınamadı'
    });
  }
});

module.exports = router;

