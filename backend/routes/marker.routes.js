const express = require('express');
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

// Helper: Session kontrolü ve kullanıcı bilgisi alma
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

// Middleware: Session doğrulama
async function authenticateUser(req, res, next) {
  try {
    const sessionId = req.cookies?.sessionId || req.headers['x-session-id'];

    if (!sessionId) {
      return res.status(401).json({
        success: false,
        message: 'Oturum bulunamadı. Lütfen giriş yapın.'
      });
    }

    const user = await verifySession(sessionId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Geçersiz oturum. Lütfen tekrar giriş yapın.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({
      success: false,
      message: 'Sunucu hatası'
    });
  }
}

// Marker oluştur
router.post('/', authenticateUser, [
  body('type').isIn(['food', 'water']).withMessage('Geçersiz marker tipi'),
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Geçersiz enlem'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Geçersiz boylam'),
  body('petType').optional().isIn(['cat', 'dog']).withMessage('Geçersiz pet tipi'),
  body('waterLiters').optional().isFloat({ min: 0 }).withMessage('Geçersiz su miktarı'),
  body('isWaterEnough').optional().isIn(['yes', 'maybe']).withMessage('Geçersiz yeterlilik durumu'),
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

    const { type, latitude, longitude, petType, waterLiters, isWaterEnough } = req.body;
    const userId = req.user.id;

    // Marker ID oluştur
    const markerId = uuidv4();

    // Marker verilerini oluştur
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

    // Redis'e kaydet
    await redisClient.set(`marker:${markerId}`, JSON.stringify(markerData));

    // Kullanıcının marker listesine ekle
    await redisClient.sAdd(`markers:user:${userId}`, markerId);

    // Tüm marker listesine ekle
    await redisClient.sAdd('markers:all', markerId);

    res.status(201).json({
      success: true,
      message: 'Marker başarıyla oluşturuldu',
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
      message: 'Marker oluşturulurken bir hata oluştu'
    });
  }
});

// Tüm marker'ları getir (yakınlık bazlı filtreleme opsiyonel)
router.get('/', async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Veritabanı bağlantısı yok'
      });
    }

    const { latitude, longitude, radius } = req.query;

    // Tüm marker ID'lerini al
    const markerIds = await redisClient.sMembers('markers:all');

    if (!markerIds || markerIds.length === 0) {
      return res.status(200).json({
        success: true,
        markers: []
      });
    }

    // Marker verilerini al
    const markers = [];
    for (const markerId of markerIds) {
      const markerData = await redisClient.get(`marker:${markerId}`);
      if (markerData) {
        const marker = JSON.parse(markerData);

        // Yakınlık filtresi varsa uygula
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
          // Filtre yoksa tüm marker'ları ekle
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
      message: 'Marker\'lar getirilirken bir hata oluştu'
    });
  }
});

// Kullanıcının marker'larını getir
router.get('/my-markers', authenticateUser, async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Veritabanı bağlantısı yok'
      });
    }

    const userId = req.user.id;

    // Kullanıcının marker ID'lerini al
    const markerIds = await redisClient.sMembers(`markers:user:${userId}`);

    if (!markerIds || markerIds.length === 0) {
      return res.status(200).json({
        success: true,
        markers: []
      });
    }

    // Marker verilerini al
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
      message: 'Marker\'lar getirilirken bir hata oluştu'
    });
  }
});

// Marker getir (ID ile)
router.get('/:id', async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Veritabanı bağlantısı yok'
      });
    }

    const { id } = req.params;
    const markerData = await redisClient.get(`marker:${id}`);

    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker bulunamadı'
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
      message: 'Marker getirilirken bir hata oluştu'
    });
  }
});

// Marker güncelle
router.put('/:id', authenticateUser, [
  body('type').optional().isIn(['food', 'water']).withMessage('Geçersiz marker tipi'),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Geçersiz enlem'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Geçersiz boylam'),
  body('petType').optional().isIn(['cat', 'dog']).withMessage('Geçersiz pet tipi'),
  body('waterLiters').optional().isFloat({ min: 0 }).withMessage('Geçersiz su miktarı'),
  body('catFoodAmount').optional().custom((value) => {
    if (value === null || value === undefined) return true; // null değerleri kabul et
    const numValue = parseFloat(value);
    return !isNaN(numValue) && numValue >= 0;
  }).withMessage('Geçersiz kedi maması miktarı'),
  body('dogFoodAmount').optional().custom((value) => {
    if (value === null || value === undefined) return true; // null değerleri kabul et
    const numValue = parseFloat(value);
    return !isNaN(numValue) && numValue >= 0;
  }).withMessage('Geçersiz köpek maması miktarı'),
  body('isWaterEnough').optional().isIn(['yes', 'maybe', 'no']).withMessage('Geçersiz yeterlilik durumu'),
  body('addedAmount').optional().isFloat({ min: 0 }).withMessage('Geçersiz eklenen miktar'),
  body('addedByUserId').optional().isString().withMessage('Geçersiz kullanıcı ID'),
  body('isEnoughNow').optional().isIn(['yes', 'maybe']).withMessage('Geçersiz yeterlilik durumu'),
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

    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Veritabanı bağlantısı yok'
      });
    }

    const { id } = req.params;
    const userId = req.user.id;

    // Marker'ı kontrol et
    const markerData = await redisClient.get(`marker:${id}`);
    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker bulunamadı'
      });
    }

    const marker = JSON.parse(markerData);

    // Kullanıcı kontrolü - sadece marker sahibi değil, herkes güncelleyebilir (opinion için)
    // Ancak bazı alanlar sadece sahibi tarafından güncellenebilir
    const isOwner = marker.userId === userId;

    // Güncelleme verilerini hazırla
    const updateData = {
      ...marker,
      updatedAt: new Date().toISOString(),
    };

    if (req.body.type !== undefined && isOwner) updateData.type = req.body.type;
    if (req.body.latitude !== undefined && isOwner) updateData.latitude = parseFloat(req.body.latitude);
    if (req.body.longitude !== undefined && isOwner) updateData.longitude = parseFloat(req.body.longitude);
    if (req.body.petType !== undefined && isOwner) updateData.petType = req.body.petType || null;
    if (req.body.waterLiters !== undefined && isOwner) updateData.waterLiters = req.body.waterLiters ? parseFloat(req.body.waterLiters) : null;
    // Pet shop owner için Cat ve Dog için ayrı miktarlar
    // null değerleri de kabul et (sıfırlama için)
    if (req.body.catFoodAmount !== undefined && isOwner) {
      // null değer gönderildiğinde null olarak ayarla, aksi halde parseFloat yap
      updateData.catFoodAmount = (req.body.catFoodAmount === null || req.body.catFoodAmount === undefined)
        ? null
        : parseFloat(req.body.catFoodAmount);
    }
    if (req.body.dogFoodAmount !== undefined && isOwner) {
      // null değer gönderildiğinde null olarak ayarla, aksi halde parseFloat yap
      updateData.dogFoodAmount = (req.body.dogFoodAmount === null || req.body.dogFoodAmount === undefined)
        ? null
        : parseFloat(req.body.dogFoodAmount);
    }

    // Opinion ve ekleme işlemleri herkes tarafından yapılabilir
    if (req.body.isWaterEnough !== undefined) updateData.isWaterEnough = req.body.isWaterEnough || null;
    if (req.body.addedAmount !== undefined) updateData.addedAmount = req.body.addedAmount ? parseFloat(req.body.addedAmount) : null;
    if (req.body.addedByUserId !== undefined) updateData.addedByUserId = req.body.addedByUserId || null;
    if (req.body.isEnoughNow !== undefined) updateData.isEnoughNow = req.body.isEnoughNow || null;

    // Redis'e kaydet
    await redisClient.set(`marker:${id}`, JSON.stringify(updateData));

    res.status(200).json({
      success: true,
      message: 'Marker başarıyla güncellendi',
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
      message: 'Marker güncellenirken bir hata oluştu'
    });
  }
});

// Marker sil
router.delete('/:id', authenticateUser, async (req, res) => {
  try {
    if (!checkRedisConnection()) {
      return res.status(503).json({
        success: false,
        message: 'Veritabanı bağlantısı yok'
      });
    }

    const { id } = req.params;
    const userId = req.user.id;

    // Marker'ı kontrol et
    const markerData = await redisClient.get(`marker:${id}`);
    if (!markerData) {
      return res.status(404).json({
        success: false,
        message: 'Marker bulunamadı'
      });
    }

    const marker = JSON.parse(markerData);

    // Kullanıcı kontrolü
    if (marker.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Bu marker\'ı silme yetkiniz yok'
      });
    }

    // Marker'ı sil
    await redisClient.del(`marker:${id}`);

    // Kullanıcının marker listesinden çıkar
    await redisClient.sRem(`markers:user:${userId}`, id);

    // Tüm marker listesinden çıkar
    await redisClient.sRem('markers:all', id);

    res.status(200).json({
      success: true,
      message: 'Marker başarıyla silindi'
    });
  } catch (error) {
    console.error('Error deleting marker:', error);
    res.status(500).json({
      success: false,
      message: 'Marker silinirken bir hata oluştu'
    });
  }
});

// İki nokta arasındaki mesafeyi hesapla (Haversine formülü)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Dünya yarıçapı (km)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c; // km cinsinden
  return distance;
}

module.exports = router;

