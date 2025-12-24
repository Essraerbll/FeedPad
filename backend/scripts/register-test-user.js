const axios = require('axios');

async function registerTestUser() {
  try {
    const response = await axios.post('http://localhost:3000/api/auth/register', {
      email: 'kubra@gmail.com',
      password: '111111',
      name: 'Kübra',
      username: 'kubra',
      userType: 'user'
    });
    
    console.log('✅ User registered successfully!');
    console.log(JSON.stringify(response.data, null, 2));
  } catch (error) {
    console.error('❌ Registration failed:', error.response?.data || error.message);
  }
}

registerTestUser();
