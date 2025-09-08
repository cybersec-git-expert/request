process.env.NODE_ENV = 'test';
const request = require('supertest');
// Import app without starting the listener (app.js has conditional listen)
const app = require('../app');

describe('API Health Check', () => {
  test('GET /health returns status string', async () => {
    const response = await request(app).get('/health');
    expect(['healthy','unhealthy']).toContain(response.body.status);
  });
});

describe('Authentication API', () => {
  test('POST /api/auth/register should require email or phone', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Test User' })
      .expect(400);
    // Route returns { error: 'Either email or phone is required' }
    expect(response.body.success).toBeUndefined();
    expect(response.body.error || response.body.message).toMatch(/email|phone/i);
  });

  test('POST /api/auth/login should require email or phone', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ password: 'testpassword' })
      .expect(401);
    // Login route returns { success:false, error:'...' }
    expect(response.body.success).toBe(false);
    expect(response.body.error).toBeDefined();
  });
});

describe('Categories API', () => {
  test('GET /api/categories should return categories', async () => {
    const response = await request(app)
      .get('/api/categories')
      .expect(200);

    expect(response.body.success).toBe(true);
    expect(Array.isArray(response.body.data)).toBe(true);
  });

  test('GET /api/categories with country filter', async () => {
    const response = await request(app)
      .get('/api/categories?country=LK')
      .expect(200);

    expect(response.body.success).toBe(true);
    expect(Array.isArray(response.body.data)).toBe(true);
  });
});

// Cleanup after tests
afterAll(async () => {
  // Close database connections
  const dbService = require('../services/database');
  await dbService.close();
});
