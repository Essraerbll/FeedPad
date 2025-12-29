const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const redisClient = require('../config/redis');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();

function checkRedisConnection() {
  try {
    return redisClient && typeof redisClient.isConnected === 'function' && redisClient.isConnected();
  } catch (error) {
    return false;
  }
}

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

router.post('/register', [
  body('email').isEmail().withMessage('Invalid email address'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('name').notEmpty().withMessage('Name is required'),
  body('username').optional().isLength({ min: 3 }).withMessage('Username must be at least 3 characters'),
  body('userType').isIn(['user', 'pet_shop_owner']).withMessage('Invalid user type'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: errors.array()
      });
    }

    const { email, password, name, username, userType } = req.body;

    const existingUserByEmail = await findUserByEmail(email);
    if (existingUserByEmail) {
      return res.status(400).json({
        success: false,
        message: 'This email address is already in use.'
      });
    }

    if (username) {
      const existingUserByUsername = await findUserByUsername(username);
      if (existingUserByUsername) {
        return res.status(400).json({
          success: false,
          message: 'This username is already taken.'
        });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const userId = uuidv4();

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

    await redisClient.set(`user:${userId}`, JSON.stringify(userData));
    await redisClient.set(`user:email:${email.toLowerCase()}`, userId);

    if (username) {
      await redisClient.set(`user:username:${username.toLowerCase()}`, userId);
    }

    res.status(201).json({
      success: true,
      message: 'Registration successful',
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
      message: 'An error occurred during registration'
    });
  }
});

router.post('/login', [
  body('email').isEmail().withMessage('Invalid email address'),
  body('password').notEmpty().withMessage('Password is required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation error',
        errors: errors.array()
      });
    }

    const { email, password } = req.body;

    const user = await findUserByEmail(email);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found.'
      });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect password.'
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'This account has been disabled.'
      });
    }

    const sessionId = uuidv4();
    const sessionData = {
      userId: user.id,
      email: user.email,
      createdAt: new Date().toISOString(),
    };

    await redisClient.setEx(`session:${sessionId}`, 86400, JSON.stringify(sessionData));

    user.lastLogin = new Date().toISOString();
    await redisClient.set(`user:${user.id}`, JSON.stringify(user));

    res.cookie('sessionId', sessionId, {
      httpOnly: true,
      maxAge: 86400000,
      sameSite: 'lax',
    });

    res.json({
      success: true,
      message: 'Login successful',
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
      message: 'An error occurred during login'
    });
  }
});

router.post('/logout', async (req, res) => {
  try {
    const sessionId = req.cookies?.sessionId;

    if (sessionId) {
      await redisClient.del(`session:${sessionId}`);
    }

    res.clearCookie('sessionId');
    res.json({
      success: true,
      message: 'Logout successful'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred during logout'
    });
  }
});

router.get('/me', async (req, res) => {
  try {
    const sessionId = req.cookies?.sessionId;

    if (!sessionId) {
      return res.status(401).json({
        success: false,
        message: 'Session not found'
      });
    }

    const user = await verifySession(sessionId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid session'
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
      message: 'Failed to get user information'
    });
  }
});

router.get('/user/:userId', async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const { userId } = req.params;
    const userData = await redisClient.get(`user:${userId}`);

    if (!userData) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const user = JSON.parse(userData);
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
    console.error('Get user by ID error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get user information'
    });
  }
});

module.exports = router;

