const express = require('express');
const router = express.Router();
const redisClient = require('../config/redis');

// Get user's posts
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const postsKey = `user:${userId}:posts`;
    
    const postIds = await redisClient.lRange(postsKey, 0, -1);
    const posts = [];
    
    for (const postId of postIds) {
      const postData = await redisClient.hGetAll(`post:${postId}`);
      if (postData && Object.keys(postData).length > 0) {
        posts.push({
          id: postId,
          ...postData,
          likes: parseInt(postData.likes) || 0,
          comments: parseInt(postData.comments) || 0,
          timestamp: parseInt(postData.timestamp)
        });
      }
    }
    
    // Sort by timestamp descending
    posts.sort((a, b) => b.timestamp - a.timestamp);
    
    res.json({ success: true, posts });
  } catch (error) {
    console.error('Get posts error:', error);
    res.status(500).json({ success: false, message: 'Failed to get posts' });
  }
});

// Create new post
router.post('/create', async (req, res) => {
  try {
    const { userId, caption, imageUrl, location } = req.body;
    
    if (!userId || !caption) {
      return res.status(400).json({ success: false, message: 'User ID and caption required' });
    }
    
    const postId = `post_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = Date.now();
    
    // Save post data - Redis expects key-value pairs as separate arguments
    await redisClient.hSet(`post:${postId}`, 'userId', userId);
    await redisClient.hSet(`post:${postId}`, 'caption', caption);
    await redisClient.hSet(`post:${postId}`, 'imageUrl', imageUrl || '');
    await redisClient.hSet(`post:${postId}`, 'location', location || '');
    await redisClient.hSet(`post:${postId}`, 'likes', '0');
    await redisClient.hSet(`post:${postId}`, 'comments', '0');
    await redisClient.hSet(`post:${postId}`, 'timestamp', timestamp.toString());
    
    const postData = {
      userId,
      caption,
      imageUrl: imageUrl || '',
      location: location || '',
      likes: 0,
      comments: 0,
      timestamp
    };
    
    // Add to user's posts list
    await redisClient.lPush(`user:${userId}:posts`, postId);
    
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
    const { limit = 20, offset = 0 } = req.query;
    
    const postIds = await redisClient.lRange('feed:global', offset, offset + parseInt(limit) - 1);
    const posts = [];
    
    for (const postId of postIds) {
      const postData = await redisClient.hGetAll(`post:${postId}`);
      if (postData && Object.keys(postData).length > 0) {
        // Get user info
        let userData = await redisClient.hGetAll(`user:${postData.userId}`);
        if (!userData || Object.keys(userData).length === 0) {
          const userJson = await redisClient.get(`user:${postData.userId}`);
          userData = userJson ? JSON.parse(userJson) : {};
        }

        posts.push({
          id: postId,
          ...postData,
          likes: parseInt(postData.likes) || 0,
          comments: parseInt(postData.comments) || 0,
          timestamp: parseInt(postData.timestamp),
          user: {
            name: userData.name || 'Unknown',
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
    
    if (followerId === followingId) {
      return res.status(400).json({ success: false, message: 'Cannot follow yourself' });
    }
    
    const isFollowing = await redisClient.sIsMember(`user:${followerId}:following`, followingId);
    
    if (isFollowing) {
      // Unfollow
      await redisClient.sRem(`user:${followerId}:following`, followingId);
      await redisClient.sRem(`user:${followingId}:followers`, followerId);
      res.json({ success: true, following: false });
    } else {
      // Follow
      await redisClient.sAdd(`user:${followerId}:following`, followingId);
      await redisClient.sAdd(`user:${followingId}:followers`, followerId);
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
    
    const postsCount = await redisClient.lLen(`user:${userId}:posts`);
    const followersCount = await redisClient.sCard(`user:${userId}:followers`);
    const followingCount = await redisClient.sCard(`user:${userId}:following`);
    
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

// Update user profile
router.put('/profile', async (req, res) => {
  try {
    const { userId, name, bio, profileImage } = req.body;
    
    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID required' });
    }
    
    const userKey = `user:${userId}`;
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

    if (name) userData.name = name;
    if (bio !== undefined) userData.bio = bio;
    if (profileImage !== undefined) userData.profileImage = profileImage;

    await redisClient.set(userKey, JSON.stringify(userData));

    res.json({ success: true, message: 'Profile updated', user: userData });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
});

module.exports = router;
