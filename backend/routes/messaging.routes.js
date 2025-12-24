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
    let { senderId, senderName, recipientId, recipientName, text } = req.body;

    console.log('\n=== SEND MESSAGE DEBUG ===');
    console.log('senderId:', senderId);
    console.log('recipientId (raw):', recipientId);

    if (!senderId || !recipientId || !text) {
      return res.status(400).json({
        success: false,
        message: 'Eksik bilgi (senderId, recipientId, text gerekli)'
      });
    }

    // If recipientId is UUID, resolve to email
    if (recipientId.includes('-') && !recipientId.includes('@')) {
      console.log('recipientId is UUID, resolving to email...');
      try {
        const userJson = await redisClient.get(`user:${recipientId}`);
        if (userJson) {
          const userData = JSON.parse(userJson);
          if (userData.email) {
            recipientId = userData.email;
            recipientName = userData.name || recipientName;
            console.log('Resolved to email:', recipientId);
          }
        }
      } catch (e) {
        console.error('Error resolving UUID to email:', e);
      }
    }

    console.log('senderName:', senderName);
    console.log('recipientId (resolved):', recipientId);
    console.log('recipientName:', recipientName);
    console.log('text:', text);

    const conversationId = getConversationId(senderId, recipientId);
    console.log('conversationId:', conversationId);
    
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
    // user1 ve user2'yi conversationId ile aynı sırada tut
    const sortedUsers = [
      { id: senderId, name: senderName || senderId },
      { id: recipientId, name: recipientName || recipientId }
    ].sort((a, b) => a.id.localeCompare(b.id));

    // Get username and profile image for both users
    let user1Username = '';
    let user2Username = '';
    let user1ProfileImage = '';
    let user2ProfileImage = '';
    try {
      const user1Keys = await redisClient.keys(`user:*`);
      for (const key of user1Keys) {
        const userJson = await redisClient.get(key);
        if (userJson) {
          const userData = JSON.parse(userJson);
          if (userData.email === sortedUsers[0].id) {
            user1Username = userData.username || '';
            user1ProfileImage = userData.profileImage || '';
          }
          if (userData.email === sortedUsers[1].id) {
            user2Username = userData.username || '';
            user2ProfileImage = userData.profileImage || '';
          }
        }
      }
    } catch (e) {
      console.error('Error getting usernames:', e);
    }

    const conversationMetadata = {
      id: conversationId,
      user1: sortedUsers[0].id,
      user1Name: sortedUsers[0].name,
      user1Username: user1Username,
      user1ProfileImage: user1ProfileImage,
      user2: sortedUsers[1].id,
      user2Name: sortedUsers[1].name,
      user2Username: user2Username,
      user2ProfileImage: user2ProfileImage,
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

    console.log('\n=== GET CONVERSATIONS DEBUG ===');
    console.log('userId:', userId);

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'userId gerekli'
      });
    }

    // Kullanıcının gizlediği sohbetleri al
    const hiddenConversations = await redisClient.sMembers(`hidden:conversations:${userId}`);
    console.log('Hidden conversations for user:', hiddenConversations);

    // Tüm konuşmaları taraması gerektiği için pattern ile arama yapıyoruz
    const keys = await redisClient.keys('conversation:metadata:*');
    console.log('Found metadata keys:', keys.length);
    
    const conversations = [];

    for (const key of keys) {
      const metadataStr = await redisClient.get(key);
      if (metadataStr) {
        const metadata = JSON.parse(metadataStr);
        const conversationId = key.replace('conversation:metadata:', '');
        
        // Eğer kullanıcı bu sohbeti gizlemiş ise, listeye ekleme
        if (hiddenConversations.includes(conversationId)) {
          console.log(`\nSkipping hidden conversation: ${conversationId}`);
          continue;
        }

        console.log(`\nMetadata for ${key}:`);
        console.log('  user1:', metadata.user1);
        console.log('  user2:', metadata.user2);
        console.log('  userId (looking for):', userId);
        
        // Sadece e-posta tabanlı konuşmalar (UUID kalıntılarını gizle)
        if (!metadata.user1?.includes('@') || !metadata.user2?.includes('@')) {
          console.log('  ⚠️ Skipping legacy/uuid conversation');
          continue;
        }

        // Eğer kullanıcı bu konuşmada varsa, ekle
        if (metadata.user1 === userId || metadata.user2 === userId) {
          console.log('  ✅ MATCH! Adding to conversations');

          // Helper to resolve user data safely by email (handles uuid mapping)
          const resolveUserData = async (email) => {
            if (!email) return {};
            let canonicalId = email;
            try {
              const resolved = await redisClient.get(`user:email:${email.toLowerCase()}`);
              if (resolved) canonicalId = resolved;
            } catch {}

            try {
              const userJson = await redisClient.get(`user:${canonicalId}`);
              if (userJson) return JSON.parse(userJson);
              const userHash = await redisClient.hGetAll(`user:${canonicalId}`);
              return userHash || {};
            } catch (e) {
              console.error('  ❌ resolveUserData error:', e);
              return {};
            }
          };

          // If username or profile image is missing, fetch it from user profile without scanning all keys
          if (!metadata.user1Username || !metadata.user2Username || !metadata.user1ProfileImage || !metadata.user2ProfileImage) {
            console.log('  ⚠️ Username or profile image missing, fetching from user profiles...');
            try {
              const user1Data = await resolveUserData(metadata.user1);
              const user2Data = await resolveUserData(metadata.user2);

              if (!metadata.user1Username) metadata.user1Username = user1Data.username || '';
              if (!metadata.user1ProfileImage) metadata.user1ProfileImage = user1Data.profileImage || '';
              if (!metadata.user2Username) metadata.user2Username = user2Data.username || '';
              if (!metadata.user2ProfileImage) metadata.user2ProfileImage = user2Data.profileImage || '';

              await redisClient.set(key, JSON.stringify(metadata));
              console.log('  ✅ Updated metadata with usernames and profile images');
            } catch (e) {
              console.error('  ❌ Error fetching usernames:', e);
            }
          }

          // conversationId'yi metadata'ya ekle
          const conversationId = key.replace('conversation:metadata:', '');
          conversations.push({ ...metadata, id: conversationId });
        } else {
          console.log('  ❌ No match');
        }
      }
    }

    console.log('\nTotal conversations found:', conversations.length);

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
    let { userId, otherUserId } = req.params;

    if (!userId || !otherUserId) {
      return res.status(400).json({
        success: false,
        message: 'userId ve otherUserId gerekli'
      });
    }

    // UUID'leri email'e çevir (eğer gerekirse)
    if (userId.includes('-') && !userId.includes('@')) {
      try {
        const userJson = await redisClient.get(`user:${userId}`);
        if (userJson) {
          const userData = JSON.parse(userJson);
          if (userData.email) {
            userId = userData.email;
          }
        }
      } catch (e) {
        console.error('Error resolving userId UUID:', e);
      }
    }

    if (otherUserId.includes('-') && !otherUserId.includes('@')) {
      try {
        const userJson = await redisClient.get(`user:${otherUserId}`);
        if (userJson) {
          const userData = JSON.parse(userJson);
          if (userData.email) {
            otherUserId = userData.email;
          }
        }
      } catch (e) {
        console.error('Error resolving otherUserId UUID:', e);
      }
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

// Mesaj sil
router.delete('/message/:conversationId/:messageId', async (req, res) => {
  try {
    const { conversationId, messageId } = req.params;
    const { userId } = req.query; // İsteği yapan kullanıcı

    if (!conversationId || !messageId || !userId) {
      return res.status(400).json({
        success: false,
        message: 'Eksik parametre (conversationId, messageId, userId gerekli)'
      });
    }

    console.log('\n=== DELETE MESSAGE DEBUG ===');
    console.log('conversationId:', conversationId);
    console.log('messageId:', messageId);
    console.log('userId (who is deleting):', userId);

    // Tüm mesajları al
    const messagesStr = await redisClient.lRange(
      `conversation:${conversationId}`,
      0,
      -1
    );

    // Silinecek mesajı bul
    let messageToDelete = null;
    let messageIndex = -1;

    for (let i = 0; i < messagesStr.length; i++) {
      const msg = JSON.parse(messagesStr[i]);
      if (msg.id === messageId) {
        messageToDelete = msg;
        messageIndex = i;
        break;
      }
    }

    if (!messageToDelete) {
      return res.status(404).json({
        success: false,
        message: 'Mesaj bulunamadı'
      });
    }

    // Sadece gönderici silebilsin
    if (messageToDelete.senderId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Yalnızca kendi mesajınızı silebilirsiniz'
      });
    }

    // Mesajı Redis listesinden sil
    // lRange 0 ile messageIndex-1 arası + messageIndex+1 ile -1 arası al
    const beforeDelete = messagesStr.slice(0, messageIndex);
    const afterDelete = messagesStr.slice(messageIndex + 1);
    const remainingMessages = [...beforeDelete, ...afterDelete];

    // Listeyi sil ve yeniden oluştur
    await redisClient.del(`conversation:${conversationId}`);
    if (remainingMessages.length > 0) {
      for (const msg of remainingMessages.reverse()) {
        await redisClient.lPush(`conversation:${conversationId}`, msg);
      }
    }

    console.log('Message deleted successfully');

    res.json({
      success: true,
      message: 'Mesaj silindi'
    });
  } catch (error) {
    console.error('Delete message error:', error);
    res.status(500).json({
      success: false,
      message: 'Mesaj silme hatası'
    });
  }
});

// Sohbeti sil
router.delete('/conversation/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { userId } = req.query;

    if (!conversationId || !userId) {
      return res.status(400).json({
        success: false,
        message: 'Eksik parametre (conversationId, userId gerekli)'
      });
    }

    console.log('\n=== DELETE CONVERSATION DEBUG ===');
    console.log('conversationId:', conversationId);
    console.log('userId (who is deleting):', userId);

    // Sohbetin metadata'sını al (JSON string)
    const metadataKey = `conversation:metadata:${conversationId}`;
    const metadataStr = await redisClient.get(metadataKey);
    if (!metadataStr) {
      return res.status(404).json({
        success: false,
        message: 'Sohbet bulunamadı'
      });
    }
    let metadata;
    try {
      metadata = JSON.parse(metadataStr);
    } catch (e) {
      console.error('Metadata parse error (delete):', e);
      return res.status(500).json({ success: false, message: 'Metadata parse hatası' });
    }

    // Mesajları sil
    await redisClient.del(`conversation:${conversationId}`);
    
    // Metadata'yı sil
    await redisClient.del(metadataKey);

    console.log('Conversation deleted successfully');

    res.json({
      success: true,
      message: 'Sohbet silindi'
    });
  } catch (error) {
    console.error('Delete conversation error:', error);
    res.status(500).json({
      success: false,
      message: 'Sohbet silme hatası'
    });
  }
});

// Sohbeti sadece kendisi için gizle (soft delete)
router.post('/conversation/hide', async (req, res) => {
  try {
    const { conversationId, userId } = req.body;

    if (!conversationId || !userId) {
      return res.status(400).json({
        success: false,
        message: 'Eksik parametre (conversationId, userId gerekli)'
      });
    }

    console.log('\n=== HIDE CONVERSATION DEBUG ===');
    console.log('conversationId:', conversationId);
    console.log('userId (who is hiding):', userId);

    // Sohbetin metadata'sını al (JSON string)
    const metadataKey = `conversation:metadata:${conversationId}`;
    const metadataStr = await redisClient.get(metadataKey);
    if (!metadataStr) {
      return res.status(404).json({
        success: false,
        message: 'Sohbet bulunamadı'
      });
    }
    try {
      JSON.parse(metadataStr); // sadece doğrulama için
    } catch (e) {
      console.error('Metadata parse error (hide):', e);
      return res.status(500).json({ success: false, message: 'Metadata parse hatası' });
    }

    // Gizli sohbetler listesine ekle
    await redisClient.sAdd(`hidden:conversations:${userId}`, conversationId);

    console.log('Conversation hidden for user:', userId);

    res.json({
      success: true,
      message: 'Sohbet gizlendi'
    });
  } catch (error) {
    console.error('Hide conversation error:', error);
    res.status(500).json({
      success: false,
      message: 'Sohbet gizleme hatası'
    });
  }
});

module.exports = router;