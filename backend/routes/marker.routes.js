const express = require('express');
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

async function authenticateUser(req, res, next) {
  try {
    const sessionId = req.cookies?.sessionId || req.headers['x-session-id'];

    if (!sessionId) {
      return res.status(401).json({
        success: false,
        message: 'Session not found. Please log in.'
      });
    }

    const user = await verifySession(sessionId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid session. Please log in again.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
}

router.post('/', authenticateUser, [
  body('type').isIn(['food', 'water']).withMessage('Invalid marker type'),
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
  body('petType').optional().isIn(['cat', 'dog']).withMessage('Invalid pet type'),
  body('waterLiters').optional().isFloat({ min: 0 }).withMessage('Invalid water amount'),
  body('isWaterEnough').optional().isIn(['yes', 'maybe']).withMessage('Invalid sufficiency status'),
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

    const { type, latitude, longitude, petType, waterLiters, isWaterEnough } = req.body;
    const userId = req.user.id;

    const markerId = uuidv4();

    const markerData = {
      id: markerId,
      userId,
      type,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      petType: petType || null,
      waterLiters: waterLiters ? parseFloat(waterLiters) : null,
      catFoodAmount: null,
      dogFoodAmount: null,
      isWaterEnough: isWaterEnough || null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await redisClient.set(`marker:${markerId}`, JSON.stringify(markerData));

    await redisClient.sAdd(`markers:user:${userId}`, markerId);

    await redisClient.sAdd('markers:all', markerId);

    res.status(201).json({
      success: true,
      message: 'Marker created successfully',
      marker: {
        id: markerData.id,
        userId: markerData.userId,
        type: markerData.type,
        latitude: markerData.latitude,
        longitude: markerData.longitude,
        petType: markerData.petType,
        waterLiters: markerData.waterLiters,
        catFoodAmount: markerData.catFoodAmount || null,
        dogFoodAmount: markerData.dogFoodAmount || null,
        isWaterEnough: markerData.isWaterEnough,
        createdAt: markerData.createdAt,
      }
    });
  } catch (error) {
    console.error('Error creating marker:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while creating marker'
    });
  }
});

router.get('/', async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const { latitude, longitude, radius } = req.query;

    const markerIds = await redisClient.sMembers('markers:all');

    if (!markerIds || markerIds.length === 0) {
      return res.status(200).json({
        success: true,
        markers: []
      });
    }

    const markers = [];
    for (const markerId of markerIds) {
      const markerData = await redisClient.get(`marker:${markerId}`);
      if (markerData) {
        const marker = JSON.parse(markerData);

        if (latitude && longitude && radius) {
          const distance = calculateDistance(
            parseFloat(latitude),
            parseFloat(longitude),
            marker.latitude,
            marker.longitude
          );

          if (distance <= parseFloat(radius)) {
            markers.push({
              id: marker.id,
              userId: marker.userId,
              type: marker.type,
              latitude: marker.latitude,
              longitude: marker.longitude,
              petType: marker.petType,
              waterLiters: marker.waterLiters,
              catFoodAmount: marker.catFoodAmount || null,
              dogFoodAmount: marker.dogFoodAmount || null,
              isWaterEnough: marker.isWaterEnough,
              addedAmount: marker.addedAmount || null,
              addedByUserId: marker.addedByUserId || null,
              isEnoughNow: marker.isEnoughNow || null,
              createdAt: marker.createdAt,
            });
          }
        } else {
          markers.push({
            id: marker.id,
            userId: marker.userId,
            type: marker.type,
            latitude: marker.latitude,
            longitude: marker.longitude,
            petType: marker.petType,
            waterLiters: marker.waterLiters,
            catFoodAmount: marker.catFoodAmount || null,
            dogFoodAmount: marker.dogFoodAmount || null,
            isWaterEnough: marker.isWaterEnough,
            addedAmount: marker.addedAmount || null,
            addedByUserId: marker.addedByUserId || null,
            isEnoughNow: marker.isEnoughNow || null,
            createdAt: marker.createdAt,
          });
        }
      }
    }

    res.status(200).json({
      success: true,
      markers
    });
  } catch (error) {
    console.error('Error fetching markers:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while fetching markers'
    });
  }
});

router.get('/my-markers', authenticateUser, async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const userId = req.user.id;

    const markerIds = await redisClient.sMembers(`markers:user:${userId}`);

    if (!markerIds || markerIds.length === 0) {
      return res.status(200).json({
        success: true,
        markers: []
      });
    }

    const markers = [];
    for (const markerId of markerIds) {
      const markerData = await redisClient.get(`marker:${markerId}`);
      if (markerData) {
        const marker = JSON.parse(markerData);
        markers.push({
          id: marker.id,
          userId: marker.userId,
          type: marker.type,
          latitude: marker.latitude,
          longitude: marker.longitude,
          petType: marker.petType,
          waterLiters: marker.waterLiters,
          catFoodAmount: marker.catFoodAmount || null,
          dogFoodAmount: marker.dogFoodAmount || null,
          isWaterEnough: marker.isWaterEnough,
          addedAmount: marker.addedAmount || null,
          addedByUserId: marker.addedByUserId || null,
          isEnoughNow: marker.isEnoughNow || null,
          createdAt: marker.createdAt,
        });
      }
    }

    res.status(200).json({
      success: true,
      markers
    });
  } catch (error) {
    console.error('Error fetching user markers:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while fetching markers'
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const { id } = req.params;
    const markerData = await redisClient.get(`marker:${id}`);

    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker not found'
      });
    }

    const marker = JSON.parse(markerData);
    res.status(200).json({
      success: true,
      marker: {
        id: marker.id,
        userId: marker.userId,
        type: marker.type,
        latitude: marker.latitude,
        longitude: marker.longitude,
        petType: marker.petType,
        waterLiters: marker.waterLiters,
        catFoodAmount: marker.catFoodAmount || null,
        dogFoodAmount: marker.dogFoodAmount || null,
        isWaterEnough: marker.isWaterEnough,
        addedAmount: marker.addedAmount || null,
        addedByUserId: marker.addedByUserId || null,
        isEnoughNow: marker.isEnoughNow || null,
        createdAt: marker.createdAt,
      }
    });
  } catch (error) {
    console.error('Error fetching marker:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while fetching marker'
    });
  }
});

router.put('/:id', authenticateUser, [
  body('type').optional().isIn(['food', 'water']).withMessage('Invalid marker type'),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
  body('petType').optional().isIn(['cat', 'dog']).withMessage('Invalid pet type'),
  body('waterLiters').optional().isFloat({ min: 0 }).withMessage('Invalid water amount'),
  body('catFoodAmount').optional().custom((value) => {
    if (value === null || value === undefined) return true;
    const numValue = parseFloat(value);
    return !isNaN(numValue) && numValue >= 0;
  }).withMessage('Invalid cat food amount'),
  body('dogFoodAmount').optional().custom((value) => {
    if (value === null || value === undefined) return true;
    const numValue = parseFloat(value);
    return !isNaN(numValue) && numValue >= 0;
  }).withMessage('Invalid dog food amount'),
  body('isWaterEnough').optional().isIn(['yes', 'maybe', 'no']).withMessage('Invalid sufficiency status'),
  body('addedAmount').optional().isFloat({ min: 0 }).withMessage('Invalid added amount'),
  body('addedByUserId').optional().isString().withMessage('Invalid user ID'),
  body('isEnoughNow').optional().isIn(['yes', 'maybe']).withMessage('Invalid sufficiency status'),
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

    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const { id } = req.params;
    const userId = req.user.id;

    const markerData = await redisClient.get(`marker:${id}`);
    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker not found'
      });
    }

    const marker = JSON.parse(markerData);

    const isOwner = marker.userId === userId;

    const updateData = {
      ...marker,
      updatedAt: new Date().toISOString(),
    };

    if (req.body.type !== undefined && isOwner) updateData.type = req.body.type;
    if (req.body.latitude !== undefined && isOwner) updateData.latitude = parseFloat(req.body.latitude);
    if (req.body.longitude !== undefined && isOwner) updateData.longitude = parseFloat(req.body.longitude);
    if (req.body.petType !== undefined && isOwner) updateData.petType = req.body.petType || null;
    if (req.body.waterLiters !== undefined && isOwner) updateData.waterLiters = req.body.waterLiters ? parseFloat(req.body.waterLiters) : null;
    if (req.body.catFoodAmount !== undefined && isOwner) {
      updateData.catFoodAmount = (req.body.catFoodAmount === null || req.body.catFoodAmount === undefined)
        ? null
        : parseFloat(req.body.catFoodAmount);
    }
    if (req.body.dogFoodAmount !== undefined && isOwner) {
      updateData.dogFoodAmount = (req.body.dogFoodAmount === null || req.body.dogFoodAmount === undefined)
        ? null
        : parseFloat(req.body.dogFoodAmount);
    }

    if (req.body.isWaterEnough !== undefined) updateData.isWaterEnough = req.body.isWaterEnough || null;
    if (req.body.addedAmount !== undefined) updateData.addedAmount = req.body.addedAmount ? parseFloat(req.body.addedAmount) : null;
    if (req.body.addedByUserId !== undefined) updateData.addedByUserId = req.body.addedByUserId || null;
    if (req.body.isEnoughNow !== undefined) updateData.isEnoughNow = req.body.isEnoughNow || null;

    await redisClient.set(`marker:${id}`, JSON.stringify(updateData));

    res.status(200).json({
      success: true,
      message: 'Marker updated successfully',
      marker: {
        id: updateData.id,
        userId: updateData.userId,
        type: updateData.type,
        latitude: updateData.latitude,
        longitude: updateData.longitude,
        petType: updateData.petType,
        waterLiters: updateData.waterLiters,
        catFoodAmount: updateData.catFoodAmount || null,
        dogFoodAmount: updateData.dogFoodAmount || null,
        isWaterEnough: updateData.isWaterEnough,
        addedAmount: updateData.addedAmount || null,
        addedByUserId: updateData.addedByUserId || null,
        isEnoughNow: updateData.isEnoughNow || null,
        createdAt: updateData.createdAt,
        updatedAt: updateData.updatedAt,
      }
    });
  } catch (error) {
    console.error('Error updating marker:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while updating marker'
    });
  }
});

router.delete('/:id', authenticateUser, async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Database connection unavailable'
      });
    }

    const { id } = req.params;
    const userId = req.user.id;

    const markerData = await redisClient.get(`marker:${id}`);
    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker not found'
      });
    }

    const marker = JSON.parse(markerData);

    if (marker.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to delete this marker'
      });
    }

    await redisClient.del(`marker:${id}`);

    await redisClient.sRem(`markers:user:${userId}`, id);

    await redisClient.sRem('markers:all', id);

    res.status(200).json({
      success: true,
      message: 'Marker deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting marker:', error);
    res.status(500).json({
      success: false,
      message: 'An error occurred while deleting marker'
    });
  }
});

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  return distance;
}

module.exports = router;

