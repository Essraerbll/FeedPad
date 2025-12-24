const express = require('express');
const router = express.Router();
const redisClient = require('../config/redis');

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

// Create new post
router.post('/create', async (req, res) => {
  try {
    const { userId, userName, caption, imageUrl, location } = req.body;
    
    if (!userId || !caption) {
      return res.status(400).json({ success: false, message: 'User ID and caption required' });
    }
    
    const postId = `post_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const timestamp = Date.now();
    
    // Resolve canonical userId (UUID) from email if needed and fetch user info
    let canonicalUserId = userId;
    let userData = {};
    try {
      const resolvedUserId = await redisClient.get(`user:email:${userId.toLowerCase()}`);
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

module.exports = router;