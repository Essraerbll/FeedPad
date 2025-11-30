// Test script to check if server can start
console.log('Testing server startup...');

try {
  console.log('1. Loading Redis config...');
  const redisClient = require('./config/redis');
  console.log('   ✓ Redis config loaded');
  
  console.log('2. Loading server...');
  const app = require('./server');
  console.log('   ✓ Server loaded');
  
  console.log('3. Checking Redis connection...');
  setTimeout(() => {
    if (redisClient.isConnected && redisClient.isConnected()) {
      console.log('   ✓ Redis is connected');
    } else {
      console.log('   ⚠ Redis is not connected (server will still work)');
    }
    console.log('\n✅ Server should be running on http://localhost:3000');
    console.log('Press Ctrl+C to stop');
  }, 2000);
  
} catch (error) {
  console.error('❌ Error:', error.message);
  console.error(error.stack);
  process.exit(1);
}

