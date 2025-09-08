process.env.NODE_ENV = 'test';
const request = require('supertest');
const app = require('../app');
const db = require('../services/database');

describe('Countries API', () => {
  afterAll(async () => {
    await db.close();
  });

  test('GET /api/countries returns array with LK seed', async () => {
    const res = await request(app).get('/api/countries');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    const codes = res.body.data.map(c => c.code);
    expect(codes).toContain('LK');
  }, 10000);
});
