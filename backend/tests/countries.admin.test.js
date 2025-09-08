process.env.NODE_ENV = 'test';
const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../app');
const db = require('../services/database');
const authService = require('../services/auth');

/**
 * Utility to create (or fetch existing) admin user and return a bearer token.
 */
async function getAdminToken() {
  const adminEmail = 'admin_test@example.com';
  // Try find existing
  let existing = await db.queryOne('SELECT * FROM users WHERE email = $1', [adminEmail]);
  if (!existing) {
    const passwordHash = await bcrypt.hash('Secret123!', 10);
    existing = await db.queryOne(`INSERT INTO users (email, password_hash, display_name, role, is_active, email_verified, phone_verified, country_code, created_at, updated_at)
      VALUES ($1,$2,$3,'admin',true,true,true,'LK',NOW(),NOW()) RETURNING *`, [adminEmail, passwordHash, 'Admin Test']);
  } else if (existing.role !== 'admin') {
    // Promote to admin if needed
    existing = await db.queryOne('UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2 RETURNING *', ['admin', existing.id]);
  }
  const token = authService.generateToken({
    id: existing.id,
    email: existing.email,
    phone: existing.phone,
    role: existing.role,
    email_verified: existing.email_verified,
    phone_verified: existing.phone_verified
  });
  return token;
}

// Generate a quasi-unique 3-letter country code for tests (avoids collisions if run multiple times)
function generateTestCode() {
  const n = (Date.now() % 17576); // 26^3
  const a = String.fromCharCode(65 + Math.floor(n / 676));
  const b = String.fromCharCode(65 + Math.floor((n % 676) / 26));
  const c = String.fromCharCode(65 + (n % 26));
  return a + b + c;
}

describe('Countries Admin CRUD API', () => {
  let adminToken;
  let testCode;

  beforeAll(async () => {
    adminToken = await getAdminToken();
    testCode = generateTestCode();
  });

  afterAll(async () => {
    await db.close();
  });

  test('Admin can create country', async () => {
    const res = await request(app)
      .post('/api/countries')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        code: testCode,
        name: 'Testland ' + testCode,
        default_currency: 'TST',
        phone_prefix: '+999',
        locale: 'en-TST',
        tax_rate: 0.15,
        flag_url: 'https://example.com/flags/' + testCode.toLowerCase() + '.png',
        is_active: true
      });
    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.code).toBe(testCode);
  }, 15000);

  test('Admin can update country', async () => {
    const newName = 'Testlandia ' + testCode;
    const res = await request(app)
      .put(`/api/countries/${testCode}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: newName, tax_rate: 0.2 });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.name).toBe(newName);
    expect(Number(res.body.data.tax_rate)).toBeCloseTo(0.2);
  }, 15000);

  test('Admin can deactivate (soft delete) country', async () => {
    const res = await request(app)
      .delete(`/api/countries/${testCode}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.is_active).toBe(false);
  }, 15000);

  test('Creating duplicate country code returns 409', async () => {
    // Attempt creating same code again should 409
    const res = await request(app)
      .post('/api/countries')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ code: testCode, name: 'Duplicate Land' });
    expect(res.status).toBe(409);
  }, 15000);
});
