const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const router = express.Router();
const redisClient = require('../config/redis');

// Upload config
const uploadDir = path.join(__dirname, '..', 'uploads', 'posts');
fs.mkdirSync(uploadDir, { recursive: true });
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const base = path.basename(file.originalname || 'upload', ext) || 'upload';
    const safeBase = base.replace(/[^a-zA-Z0-9_-]/g, '');
    cb(null, `${Date.now()}_${safeBase || 'file'}${ext || '.jpg'}`);
  }
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
});

const conditionalUpload = (req, res, next) => {
  if (req.is('multipart/form-data')) {
    return upload.single('image')(req, res, next);
  }
  return next();
};

const buildImageUrl = (req, filename) => {
  const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${base}/uploads/posts/${filename}`;
};

const buildProfileImageUrl = (req, filename) => {
  const base = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${base}/uploads/profiles/${filename}`;
};

// Get user's posts
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { requesterId } = req.query; // Who is requesting to check liked status
    
    // Resolve canonical userId (UUID) from email
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${userId.toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}

    const postsKeyUuid = `user:${canonicalUserId}:posts`;
    const postsKeyEmail = `user:${userId}:posts`;
    
    // Merge posts from both potential keys to avoid lost data
    const postIdsSet = new Set();
    const postIdsUuid = await redisClient.lRange(postsKeyUuid, 0, -1).catch(() => []);
    const postIdsEmail = await redisClient.lRange(postsKeyEmail, 0, -1).catch(() => []);
    for (const id of postIdsUuid) postIdsSet.add(id);
    for (const id of postIdsEmail) postIdsSet.add(id);
    const postIds = Array.from(postIdsSet);
    const posts = [];
    
    for (const postId of postIds) {
      const postData = await redisClient.hGetAll(`post:${postId}`);
      if (postData && Object.keys(postData).length > 0 && (postData.userId || '') !== '') {
        // Get comments for this post
        const commentsIds = await redisClient.lRange(`post:${postId}:comments`, 0, -1);
        const comments = [];
        
        for (const commentId of commentsIds) {
          const commentData = await redisClient.hGetAll(`comment:${commentId}`);
          if (commentData && Object.keys(commentData).length > 0) {
            // Get latest userName, username, and profileImage from user profile
            let userName = commentData.userName || 'Anonymous';
            let username = commentData.username || 'user';
            let userProfileImage = commentData.userProfileImage || '';
            try {
              const commentUserId = commentData.userId;
              if (commentUserId) {
                const userDataStr = await redisClient.get(`user:${commentUserId}`);
                if (userDataStr) {
                  const userData = JSON.parse(userDataStr);
                  if (userData.name) userName = userData.name;
                  if (userData.username) username = userData.username;
                  if (userData.profileImage) {
                    userProfileImage = userData.profileImage;
                    // Convert to full URL if it's a filename
                    if (!userProfileImage.startsWith('http') && !userProfileImage.startsWith('data:')) {
                      userProfileImage = buildProfileImageUrl(req, userProfileImage);
                    }
                  }
                }
              }
            } catch {}
            
            comments.push({
              id: commentId,
              ...commentData,
              userName: userName,
              username: username,
              userProfileImage: userProfileImage,
              timestamp: parseInt(commentData.timestamp)
            });
            
            console.log(`Comment user: ${userName}, profileImage: ${userProfileImage}`);
          }
        }
        
        // Get user info for the post
        // Get user info - try email lookup first
        let userIdKey = postData.userId || '';
        try {
          if (typeof userIdKey === 'string' && userIdKey.length > 0) {
            const emailKey = `user:email:${userIdKey.toLowerCase()}`;
            const userIdByEmail = await redisClient.get(emailKey);
            if (userIdByEmail) {
              userIdKey = userIdByEmail;
            }
          }
        } catch {}
        
        let userData = {};
        try {
          const userJson = await redisClient.get(`user:${userIdKey}`);
          if (userJson) {
            userData = JSON.parse(userJson);
          } else {
            userData = await redisClient.hGetAll(`user:${userIdKey}`);
          }
        } catch {}
        
        // Convert profile image to full URL if it's a filename
        if (userData.profileImage && !userData.profileImage.startsWith('http') && !userData.profileImage.startsWith('data:')) {
          userData.profileImage = buildProfileImageUrl(req, userData.profileImage);
        }
        
        console.log('Post owner userData:', { name: userData.name, profileImage: userData.profileImage });
        
        // Check if requester liked this post
        let liked = false;
        if (requesterId) {
          try {
            liked = await redisClient.sIsMember(`post:${postId}:likes`, requesterId);
          } catch {}
        }
        
        posts.push({
          id: postId,
          ...postData,
          likes: parseInt(postData.likes) || 0,
          liked: liked,
          comments: comments,
          timestamp: parseInt(postData.timestamp),
          user: {
            name: postData.userName || userData.name || 'User',
            username: userData.username || 'user',
            profileImage: userData.profileImage || null
          }
        });
      }
    }
    
    // Sort by timestamp descending
    posts.sort((a, b) => b.timestamp - a.timestamp);
    
    // Get user's bio and profile image to return as well
    let userBio = null;
    let userProfileImage = null;
    try {
      const userJson = await redisClient.get(`user:${canonicalUserId}`);
      const userData = userJson ? JSON.parse(userJson) : {};
      userBio = userData.bio || null;
      userProfileImage = userData.profileImage || null;
    } catch {}
    
    res.json({ 
      success: true, 
      posts, 
      user: { 
        bio: userBio,
        profileImage: userProfileImage
      } 
    });
  } catch (error) {
    console.error('Get posts error:', error);
    res.status(500).json({ success: false, message: 'Failed to get posts' });
  }
});

// Create new post (supports JSON or multipart/form-data with image)
router.post('/create', conditionalUpload, async (req, res) => {
  try {
    const { userId, userName, caption, location } = req.body;
    
    console.log('Create post request:');
    console.log('Body:', req.body);
    console.log('File:', req.file ? `${req.file.filename} (${req.file.size} bytes)` : 'None');
    console.log('userId:', userId);
    console.log('caption:', caption);
    
    if (!userId || !caption) {
      return res.status(400).json({ success: false, message: 'User ID and caption required' });
    }
    
    const postId = `post_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = Date.now();
    
    // Resolve canonical userId (UUID) from email if needed and fetch user info
    let canonicalUserId = userId;
    let userData = {};
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
      const userJson = await redisClient.get(`user:${canonicalUserId}`);
      if (userJson) {
        userData = JSON.parse(userJson);
      }
    } catch (e) {
      console.log('Could not fetch user data:', e);
    }
    
    let imageUrl = req.body.imageUrl || '';
    if (req.file) {
      imageUrl = buildImageUrl(req, req.file.filename);
    }
    
    // Save post data - Redis expects key-value pairs as separate arguments
    await redisClient.hSet(`post:${postId}`, 'userId', canonicalUserId);
    await redisClient.hSet(`post:${postId}`, 'userName', userName || userData.name || 'User');
    await redisClient.hSet(`post:${postId}`, 'caption', caption);
    await redisClient.hSet(`post:${postId}`, 'imageUrl', imageUrl || '');
    await redisClient.hSet(`post:${postId}`, 'location', location || '');
    await redisClient.hSet(`post:${postId}`, 'likes', '0');
    await redisClient.hSet(`post:${postId}`, 'comments', '0');
    await redisClient.hSet(`post:${postId}`, 'timestamp', timestamp.toString());
    
    const postData = {
      userId: canonicalUserId,
      userName: userName || userData.name || 'User',
      caption,
      imageUrl: imageUrl || '',
      location: location || '',
      likes: 0,
      comments: 0,
      timestamp,
      user: {
        id: canonicalUserId,
        email: userData.email || '',
        name: userData.name || 'User',
        username: userData.username || 'user',
        profileImage: userData.profileImage || null,
        bio: userData.bio || null
      }
    };
    
    // Add to user's posts list
    await redisClient.lPush(`user:${canonicalUserId}:posts`, postId);
    
    // Add to global feed
    await redisClient.lPush('feed:global', postId);
    
    res.json({ success: true, postId, post: { id: postId, ...postData } });
  } catch (error) {
    console.error('Create post error:', error);
    res.status(500).json({ success: false, message: 'Failed to create post' });
  }
});

// Get global feed
router.get('/feed', async (req, res) => {
  try {
    const { limit = 20, offset = 0, requesterId } = req.query; // Who is requesting to check liked status
    
    const postIds = await redisClient.lRange('feed:global', offset, offset + parseInt(limit) - 1);
    const posts = [];
    
    for (const postId of postIds) {
      const postData = await redisClient.hGetAll(`post:${postId}`);
      if (postData && Object.keys(postData).length > 0 && (postData.userId || '') !== '') {
        // Get comments for this post
        const commentsIds = await redisClient.lRange(`post:${postId}:comments`, 0, -1);
        const comments = [];
        
        for (const commentId of commentsIds) {
          const commentData = await redisClient.hGetAll(`comment:${commentId}`);
          if (commentData && Object.keys(commentData).length > 0) {
            // Get latest userName and username from user profile
            let userName = commentData.userName || 'Anonymous';
            let username = commentData.username || 'user';
            try {
              const commentUserId = commentData.userId;
              if (commentUserId) {
                const userDataStr = await redisClient.get(`user:${commentUserId}`);
                if (userDataStr) {
                  const userData = JSON.parse(userDataStr);
                  if (userData.name) userName = userData.name;
                  if (userData.username) username = userData.username;
                }
              }
            } catch {}
            
            comments.push({
              id: commentId,
              ...commentData,
              userName: userName,
              username: username,
              timestamp: parseInt(commentData.timestamp)
            });
          }
        }
        
        // Get user info
        // Get user info - try email lookup first
        let userIdKey = postData.userId || '';
        try {
          if (typeof userIdKey === 'string' && userIdKey.length > 0) {
            const emailKey = `user:email:${userIdKey.toLowerCase()}`;
            const userIdByEmail = await redisClient.get(emailKey);
            if (userIdByEmail) {
              userIdKey = userIdByEmail;
            }
          }
        } catch {}
        
        let userData = {};
        try {
          const userJson = await redisClient.get(`user:${userIdKey}`);
          if (userJson) {
            userData = JSON.parse(userJson);
          } else {
            userData = await redisClient.hGetAll(`user:${userIdKey}`);
          }
        } catch {}

        // Check if requester liked this post
        let liked = false;
        if (requesterId) {
          try {
            liked = await redisClient.sIsMember(`post:${postId}:likes`, requesterId);
          } catch {}
        }

        posts.push({
          id: postId,
          ...postData,
          likes: parseInt(postData.likes) || 0,
          liked: liked,
          comments: comments,
          timestamp: parseInt(postData.timestamp),
          user: {
            id: userIdKey,
            email: userData.email || '',
            name: postData.userName || userData.name || 'User',
            username: userData.username || 'user',
            profileImage: userData.profileImage || null
          }
        });
      }
    }

    res.json({ success: true, posts });
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({ success: false, message: 'Failed to get feed' });
  }
});

// Like/Unlike post
router.post('/like', async (req, res) => {
  try {
    const { postId, userId } = req.body;
    
    if (!postId || !userId) {
      return res.status(400).json({ success: false, message: 'Post ID and User ID required' });
    }
    
    const likeKey = `post:${postId}:likes`;
    const isLiked = await redisClient.sIsMember(likeKey, userId);
    
    if (isLiked) {
      // Unlike
      await redisClient.sRem(likeKey, userId);
      await redisClient.hIncrBy(`post:${postId}`, 'likes', -1);
      res.json({ success: true, liked: false });
    } else {
      // Like
      await redisClient.sAdd(likeKey, userId);
      await redisClient.hIncrBy(`post:${postId}`, 'likes', 1);
      res.json({ success: true, liked: true });
    }
  } catch (error) {
    console.error('Like post error:', error);
    res.status(500).json({ success: false, message: 'Failed to like post' });
  }
});

// Follow/Unfollow user
router.post('/follow', async (req, res) => {
  try {
    const { followerId, followingId } = req.body;
    
    if (!followerId || !followingId) {
      return res.status(400).json({ success: false, message: 'Follower and Following IDs required' });
    }
    
    // Resolve canonical userIds (UUID) from email if needed
    let canonicalFollowerId = followerId;
    let canonicalFollowingId = followingId;
    
    try {
      const resolvedFollowerId = await redisClient.get(`user:email:${String(followerId).toLowerCase()}`);
      if (resolvedFollowerId) {
        canonicalFollowerId = resolvedFollowerId;
      }
    } catch {}
    
    try {
      const resolvedFollowingId = await redisClient.get(`user:email:${String(followingId).toLowerCase()}`);
      if (resolvedFollowingId) {
        canonicalFollowingId = resolvedFollowingId;
      }
    } catch {}
    
    if (canonicalFollowerId === canonicalFollowingId) {
      return res.status(400).json({ success: false, message: 'Cannot follow yourself' });
    }
    
    const isFollowing = await redisClient.sIsMember(`user:${canonicalFollowerId}:following`, canonicalFollowingId);
    
    if (isFollowing) {
      // Unfollow
      await redisClient.sRem(`user:${canonicalFollowerId}:following`, canonicalFollowingId);
      await redisClient.sRem(`user:${canonicalFollowingId}:followers`, canonicalFollowerId);
      res.json({ success: true, following: false });
    } else {
      // Follow
      await redisClient.sAdd(`user:${canonicalFollowerId}:following`, canonicalFollowingId);
      await redisClient.sAdd(`user:${canonicalFollowingId}:followers`, canonicalFollowerId);
      res.json({ success: true, following: true });
    }
  } catch (error) {
    console.error('Follow error:', error);
    res.status(500).json({ success: false, message: 'Failed to follow/unfollow' });
  }
});

// Get user stats
router.get('/stats/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Resolve canonical userId (UUID) from email if needed
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}
    
    const postsCount = await redisClient.lLen(`user:${canonicalUserId}:posts`);
    const followersCount = await redisClient.sCard(`user:${canonicalUserId}:followers`);
    const followingCount = await redisClient.sCard(`user:${canonicalUserId}:following`);
    
    res.json({
      success: true,
      stats: {
        posts: postsCount,
        followers: followersCount,
        following: followingCount
      }
    });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ success: false, message: 'Failed to get stats' });
  }
});

// Check if user is following another user
router.get('/follow/status', async (req, res) => {
  try {
    const { followerId, followingId } = req.query;
    
    if (!followerId || !followingId) {
      return res.status(400).json({ success: false, message: 'Follower and Following IDs required' });
    }
    
    // Resolve canonical userIds
    let canonicalFollowerId = followerId;
    let canonicalFollowingId = followingId;
    
    try {
      const resolvedFollowerId = await redisClient.get(`user:email:${String(followerId).toLowerCase()}`);
      if (resolvedFollowerId) canonicalFollowerId = resolvedFollowerId;
    } catch {}
    
    try {
      const resolvedFollowingId = await redisClient.get(`user:email:${String(followingId).toLowerCase()}`);
      if (resolvedFollowingId) canonicalFollowingId = resolvedFollowingId;
    } catch {}
    
    const isFollowing = await redisClient.sIsMember(`user:${canonicalFollowerId}:following`, canonicalFollowingId);
    
    res.json({ success: true, isFollowing });
  } catch (error) {
    console.error('Check follow status error:', error);
    res.status(500).json({ success: false, message: 'Failed to check follow status' });
  }
});

// Update user profile
router.put('/profile', async (req, res) => {
  try {
    const { userId, name, bio, profileImage } = req.body;
    
    console.log('=== Profile Update Debug ===');
    console.log('User ID:', userId);
    console.log('Name:', name);
    console.log('Bio:', bio ? bio.substring(0, 50) : 'null');
    console.log('Profile Image:', profileImage ? `YES (${profileImage.length} chars)` : 'NO');
    
    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID required' });
    }
    
    // Resolve canonical userId (UUID) from email if needed
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}
    
    const userKey = `user:${canonicalUserId}`;
    const existingUserJson = await redisClient.get(userKey);
    let userData = existingUserJson ? JSON.parse(existingUserJson) : null;

    // If user stored as hash, fall back to hGetAll
    if (!userData || Object.keys(userData).length === 0) {
      const userHash = await redisClient.hGetAll(userKey);
      if (userHash && Object.keys(userHash).length > 0) {
        userData = userHash;
      }
    }

    if (!userData) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    console.log('User found:', canonicalUserId);
    console.log('Before update - profileImage:', userData.profileImage ? 'EXISTS' : 'NULL');

    if (name) userData.name = name;
    if (bio !== undefined) userData.bio = bio;
    if (profileImage !== undefined) userData.profileImage = profileImage;

    console.log('After update - profileImage:', userData.profileImage ? `YES (${userData.profileImage.length} chars)` : 'NULL');

    await redisClient.set(userKey, JSON.stringify(userData));
    
    console.log('Saved to Redis:', userKey);

    // Update all posts by this user with new name
    if (name) {
      try {
        const postIds = await redisClient.lRange(`user:${canonicalUserId}:posts`, 0, -1);
        for (const postId of postIds) {
          await redisClient.hSet(`post:${postId}`, 'userName', name);
        }

        // Update all comments by this user with new name
        const feedPostIds = await redisClient.lRange('feed:global', 0, -1).catch(() => []);
        for (const postId of feedPostIds) {
          try {
            const commentIds = await redisClient.lRange(`post:${postId}:comments`, 0, -1).catch(() => []);
            for (const commentId of commentIds) {
              const commentData = await redisClient.hGetAll(`comment:${commentId}`);
              if (commentData && commentData.userId === canonicalUserId) {
                await redisClient.hSet(`comment:${commentId}`, 'userName', name);
              }
            }
          } catch (e) {
            console.log('Error updating comments for post', postId, ':', e);
          }
        }
      } catch (e) {
        console.log('Error updating posts/comments with new name:', e);
        // Don't fail the whole request, just log
      }
    }

    res.json({ success: true, message: 'Profile updated', user: userData });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
});

// Add comment to post
router.post('/comment', async (req, res) => {
  try {
    const { postId, userId, userName, text } = req.body;
    
    if (!postId || !userId || !text) {
      return res.status(400).json({ success: false, message: 'Post ID, User ID, and text required' });
    }
    
    // Resolve canonical userId (UUID) from email if needed
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}
    
    // Get user profile data
    let userProfileImage = null;
    let actualUserName = userName || 'Anonymous';
    let username = '';
    try {
      const userDataStr = await redisClient.get(`user:${canonicalUserId}`);
      if (userDataStr) {
        const userData = JSON.parse(userDataStr);
        userProfileImage = userData.profileImage || null;
        username = userData.username || '';
        if (userData.name) actualUserName = userData.name;
      }
    } catch (e) {
      console.log('Could not fetch user profile image:', e);
    }
    
    const commentId = `comment_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = Date.now();
    
    // Save comment with full user info and canonical userId
    const commentKey = `comment:${commentId}`;
    await redisClient.hSet(commentKey, 'userId', canonicalUserId);
    await redisClient.hSet(commentKey, 'userName', actualUserName);
    await redisClient.hSet(commentKey, 'username', username);
    await redisClient.hSet(commentKey, 'userProfileImage', userProfileImage || '');
    await redisClient.hSet(commentKey, 'text', text);
    await redisClient.hSet(commentKey, 'timestamp', timestamp.toString());
    
    // Add comment to post's comments list
    const postCommentsKey = `post:${postId}:comments`;
    await redisClient.lPush(postCommentsKey, commentId);
    
    // Increment post's comment count
    await redisClient.hIncrBy(`post:${postId}`, 'comments', 1);
    
    res.json({ 
      success: true, 
      commentId,
      comment: {
        id: commentId,
        userId,
        userName: userName || 'Anonymous',
        userProfileImage: userProfileImage || null,
        text,
        timestamp
      }
    });
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ success: false, message: 'Failed to add comment' });
  }
});

// Migrate a user's posts from email-based list to UUID-based list
router.post('/migrate/user-post-keys', async (req, res) => {
  try {
    const { userId } = req.body; // may be email
    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID (email) required' });
    }

    // Resolve canonical UUID
    let canonicalUserId = userId;
    const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
    if (resolvedUserId) canonicalUserId = resolvedUserId;

    const postsKeyUuid = `user:${canonicalUserId}:posts`;
    const postsKeyEmail = `user:${userId}:posts`;

    const postIdsUuid = await redisClient.lRange(postsKeyUuid, 0, -1).catch(() => []);
    const postIdsEmail = await redisClient.lRange(postsKeyEmail, 0, -1).catch(() => []);

    const uuidSet = new Set(postIdsUuid);
    let migrated = 0;
    for (const id of postIdsEmail) {
      if (!uuidSet.has(id)) {
        await redisClient.lPush(postsKeyUuid, id);
        uuidSet.add(id);
        migrated++;
      }
      // Ensure post userId is canonical
      await redisClient.hSet(`post:${id}`, 'userId', canonicalUserId);
    }

    // Optionally, remove the email-based list (leave it for safety)
    // await redisClient.del(postsKeyEmail);

    res.json({ success: true, migrated, canonicalUserId, postsTotal: uuidSet.size });
  } catch (error) {
    console.error('Migrate user post keys error:', error);
    res.status(500).json({ success: false, message: 'Failed to migrate user post keys' });
  }
});

// Delete post
router.post('/delete', async (req, res) => {
  try {
    const { postId, userId } = req.body;
    
    if (!postId || !userId) {
      return res.status(400).json({ success: false, message: 'Post ID and User ID required' });
    }
    
    // Resolve canonical userId (UUID) from email if needed
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}
    
    // Get post data to verify ownership
    const postData = await redisClient.hGetAll(`post:${postId}`);
    if (!postData || Object.keys(postData).length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }
    
    // Verify ownership
    const postOwnerId = postData.userId;
    if (postOwnerId !== canonicalUserId && postOwnerId !== userId) {
      return res.status(403).json({ success: false, message: 'Not authorized to delete this post' });
    }
    
    // Delete post hash
    await redisClient.del(`post:${postId}`);
    
    // Remove from user's posts lists
    await redisClient.lRem(`user:${canonicalUserId}:posts`, 0, postId);
    await redisClient.lRem(`user:${userId}:posts`, 0, postId);
    
    // Delete comments associated with post
    const commentsIds = await redisClient.lRange(`post:${postId}:comments`, 0, -1);
    for (const commentId of commentsIds) {
      await redisClient.del(`comment:${commentId}`);
    }
    await redisClient.del(`post:${postId}:comments`);
    
    // Delete likes set
    await redisClient.del(`post:${postId}:likes`);
    
    res.json({ success: true, message: 'Post deleted successfully' });
  } catch (error) {
    console.error('Delete post error:', error);
    res.status(500).json({ success: false, message: 'Failed to delete post' });
  }
});

// Update post
router.post('/update', async (req, res) => {
  try {
    const { postId, userId, caption, location } = req.body;
    
    if (!postId || !userId || !caption) {
      return res.status(400).json({ success: false, message: 'Post ID, User ID, and caption required' });
    }
    
    // Resolve canonical userId (UUID) from email if needed
    let canonicalUserId = userId;
    try {
      const resolvedUserId = await redisClient.get(`user:email:${String(userId).toLowerCase()}`);
      if (resolvedUserId) {
        canonicalUserId = resolvedUserId;
      }
    } catch {}
    
    // Get post data to verify ownership
    const postData = await redisClient.hGetAll(`post:${postId}`);
    if (!postData || Object.keys(postData).length === 0) {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }
    
    // Verify ownership
    const postOwnerId = postData.userId;
    if (postOwnerId !== canonicalUserId && postOwnerId !== userId) {
      return res.status(403).json({ success: false, message: 'Not authorized to update this post' });
    }
    
    // Update post data
    await redisClient.hSet(`post:${postId}`, 'caption', caption);
    if (location) {
      await redisClient.hSet(`post:${postId}`, 'location', location);
    }
    
    // Get updated post
    const updatedPostData = await redisClient.hGetAll(`post:${postId}`);
    
    res.json({ 
      success: true, 
      message: 'Post updated successfully',
      post: updatedPostData
    });
  } catch (error) {
    console.error('Update post error:', error);
    res.status(500).json({ success: false, message: 'Failed to update post' });
  }
});

// Get single post details (MUST BE LAST - generic route)
router.get('/:postId', async (req, res) => {
  try {
    const { postId } = req.params;
    const { requesterId } = req.query; // Who is requesting to check liked status
    
    console.log('=== GET Post Details ===');
    console.log('Post ID:', postId);
    console.log('Requester ID:', requesterId);
    
    const postData = await redisClient.hGetAll(`post:${postId}`);
    console.log('Post data from Redis:', postData);
    console.log('Post data keys:', Object.keys(postData));
    
    if (!postData || Object.keys(postData).length === 0) {
      console.log('ERROR: Post not found in Redis');
      return res.status(404).json({ success: false, message: 'Post not found' });
    }
    
    // Get comments for this post
    const commentsIds = await redisClient.lRange(`post:${postId}:comments`, 0, -1);
    const comments = [];
    
    for (const commentId of commentsIds) {
      const commentData = await redisClient.hGetAll(`comment:${commentId}`);
      if (commentData && Object.keys(commentData).length > 0) {
        // Get latest userName, username, and profileImage from user profile
        let userName = commentData.userName || 'Anonymous';
        let username = commentData.username || 'user';
        let userProfileImage = commentData.userProfileImage || '';
        try {
          const commentUserId = commentData.userId;
          if (commentUserId) {
            const userDataStr = await redisClient.get(`user:${commentUserId}`);
            if (userDataStr) {
              const userData = JSON.parse(userDataStr);
              if (userData.name) userName = userData.name;
              if (userData.username) username = userData.username;
              if (userData.profileImage) {
                userProfileImage = userData.profileImage;
                // Convert to full URL if it's a filename
                if (!userProfileImage.startsWith('http') && !userProfileImage.startsWith('data:')) {
                  userProfileImage = buildProfileImageUrl(req, userProfileImage);
                }
              }
            }
          }
        } catch {}
        
        comments.push({
          id: commentId,
          ...commentData,
          userName: userName,
          username: username,
          userProfileImage: userProfileImage,
          timestamp: parseInt(commentData.timestamp)
        });
      }
    }
    
    // Get user info for the post
    let userIdKey = postData.userId || '';
    try {
      if (typeof userIdKey === 'string' && userIdKey.length > 0) {
        const emailKey = `user:email:${userIdKey.toLowerCase()}`;
        const userIdByEmail = await redisClient.get(emailKey);
        if (userIdByEmail) {
          userIdKey = userIdByEmail;
        }
      }
    } catch {}
    
    let userData = {};
    try {
      const userJson = await redisClient.get(`user:${userIdKey}`);
      if (userJson) {
        userData = JSON.parse(userJson);
      } else {
        userData = await redisClient.hGetAll(`user:${userIdKey}`);
      }
    } catch {}
    
    // Convert profile image to full URL if it's a filename
    if (userData.profileImage && !userData.profileImage.startsWith('http') && !userData.profileImage.startsWith('data:')) {
      userData.profileImage = buildProfileImageUrl(req, userData.profileImage);
    }
    
    // Check if requester liked this post
    let liked = false;
    if (requesterId) {
      try {
        liked = await redisClient.sIsMember(`post:${postId}:likes`, requesterId);
      } catch {}
    }
    
    const post = {
      id: postId,
      ...postData,
      likes: parseInt(postData.likes) || 0,
      liked: liked,
      comments: comments,
      timestamp: parseInt(postData.timestamp),
      user: {
        name: postData.userName || userData.name || 'User',
        username: userData.username || 'user',
        profileImage: userData.profileImage || null
      }
    };
    
    console.log('Sending successful response with post data');
    console.log('Post:', JSON.stringify(post, null, 2));
    res.json({ success: true, post });
  } catch (error) {
    console.error('Get post details error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ success: false, message: 'Failed to get post details', error: error.message });
  }
});

module.exports = router;
