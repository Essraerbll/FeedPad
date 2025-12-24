const express = require('express');
const redisClient = require('../config/redis');
const router = express.Router();

// Helper: Konuşma ID'si oluştur (iki kullanıcı ID'sini sırala)
function getConversationId(user1, user2) {
  return [user1, user2].sort().join(':');
}

// Mesaj gönder
router.post('/send', async (req, res) => {
  try {
    const { senderId, senderName, recipientId, recipientName, text } = req.body;

    if (!senderId || !recipientId || !text) {
      return res.status(400).json({
        success: false,
        message: 'Eksik bilgi (senderId, recipientId, text gerekli)'
      });
    }

    const conversationId = getConversationId(senderId, recipientId);
    const messageId = `msg_${Date.now()}`;
    const timestamp = new Date().toISOString();

    const message = {
      id: messageId,
      senderId,
      senderName: senderName || senderId,
      recipientId,
      recipientName: recipientName || recipientId,
      text,
      timestamp,
    };

    // Mesajı Redis'e kaydet
    await redisClient.lPush(
      `conversation:${conversationId}`,
      JSON.stringify(message)
    );

    // Konuşma metadata'sını güncelle
    const conversationMetadata = {
      id: conversationId,
      user1: senderId,
      user1Name: senderName,
      user2: recipientId,
      user2Name: recipientName,
      lastMessage: text,
      lastMessageTime: timestamp,
      lastMessageBy: senderName,
    };

    await redisClient.set(
      `conversation:metadata:${conversationId}`,
      JSON.stringify(conversationMetadata)
    );

    res.json({
      success: true,
      message: 'Mesaj gönderildi',
      data: message
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({
      success: false,
      message: 'Mesaj gönderme hatası'
    });
  }
});

// Konuşmaları getir (belirli kullanıcı için)
router.get('/conversations/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'userId gerekli'
      });
    }

    // Tüm konuşmaları taraması gerektiği için pattern ile arama yapıyoruz
    const keys = await redisClient.keys('conversation:metadata:*');
    const conversations = [];

    for (const key of keys) {
      const metadataStr = await redisClient.get(key);
      if (metadataStr) {
        const metadata = JSON.parse(metadataStr);
        // Eğer kullanıcı bu konuşmada varsa, ekle
        if (metadata.user1 === userId || metadata.user2 === userId) {
          conversations.push(metadata);
        }
      }
    }

    // Son mesaj zamanına göre sırala
    conversations.sort((a, b) => {
      return new Date(b.lastMessageTime) - new Date(a.lastMessageTime);
    });

    res.json({
      success: true,
      conversations
    });
  } catch (error) {
    console.error('Get conversations error:', error);
    res.status(500).json({
      success: false,
      message: 'Konuşmalar alınamadı'
    });
  }
});

// Belirli konuşmanın mesajlarını getir
router.get('/conversation/:userId/:otherUserId', async (req, res) => {
  try {
    const { userId, otherUserId } = req.params;

    if (!userId || !otherUserId) {
      return res.status(400).json({
        success: false,
        message: 'userId ve otherUserId gerekli'
      });
    }

    const conversationId = getConversationId(userId, otherUserId);
    const messagesStr = await redisClient.lRange(
      `conversation:${conversationId}`,
      0,
      -1
    );

    // Mesajları ters sırala (eski mesajlar altta, yeni mesajlar üstte)
    const messages = messagesStr.map(msg => JSON.parse(msg)).reverse();

    // Konuşma metadata'sını al
    const metadataStr = await redisClient.get(
      `conversation:metadata:${conversationId}`
    );
    const metadata = metadataStr ? JSON.parse(metadataStr) : null;

    res.json({
      success: true,
      conversationId,
      messages,
      metadata
    });
  } catch (error) {
    console.error('Get conversation messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Mesajlar alınamadı'
    });
  }
});

module.exports = router;
