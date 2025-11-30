const redis = require('redis');
require('dotenv').config();

let redisClient = null;
let isConnected = false;

// Redis client oluştur
function createRedisClient() {
  if (redisClient) return redisClient;

  redisClient = redis.createClient({
    socket: {
      host: process.env.REDIS_HOST || 'localhost',
      port: process.env.REDIS_PORT || 6379,
      reconnectStrategy: (retries) => {
        if (retries > 10) {
          console.error('❌ Redis: Too many reconnection attempts, giving up');
          return new Error('Too many reconnection attempts');
        }
        return Math.min(retries * 100, 3000);
      }
    },
    password: process.env.REDIS_PASSWORD || undefined,
  });

  redisClient.on('error', (err) => {
    console.error('❌ Redis Client Error:', err.message);
    isConnected = false;
  });

  redisClient.on('connect', () => {
    console.log('🔄 Redis: Connecting...');
  });

  redisClient.on('ready', () => {
    console.log('✅ Redis connected successfully');
    isConnected = true;
  });

  redisClient.on('end', () => {
    console.log('⚠️ Redis: Connection ended');
    isConnected = false;
  });

  // Redis bağlantısını başlat (non-blocking)
  (async () => {
    try {
      await redisClient.connect();
    } catch (err) {
      console.error('❌ Redis connection error:', err.message);
      console.log('⚠️ Server will continue without Redis (some features may not work)');
      isConnected = false;
    }
  })();

  return redisClient;
}

// Lazy initialization
const getRedisClient = () => {
  if (!redisClient) {
    return createRedisClient();
  }
  return redisClient;
};

// Helper function to check if Redis is connected
const isRedisConnected = () => isConnected;

// Export client and connection status
const client = getRedisClient();
client.isConnected = isRedisConnected;

module.exports = client;

