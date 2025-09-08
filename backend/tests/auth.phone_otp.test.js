process.env.NODE_ENV = 'test';
const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../app');
const db = require('../services/database');

async function ensureUser(phone) {
  let user = await db.queryOne('SELECT * FROM users WHERE phone = $1', [phone]);
  if (!user) {
    const passwordHash = await bcrypt.hash('TempPass123!', 10);
    // Provide a deterministic synthetic email to satisfy NOT NULL/UNIQUE constraints
    const syntheticEmail = `phone_${phone.replace(/[^0-9]/g,'')}_${Date.now()}@example.test`;
    user = await db.queryOne(`INSERT INTO users (email, phone, password_hash, display_name, role, is_active, email_verified, phone_verified, country_code, created_at, updated_at)
      VALUES ($1,$2,$3,$4,'user',true,false,false,'LK',NOW(),NOW()) RETURNING *`, [syntheticEmail, phone, passwordHash, 'Phone OTP User']);
  } else if (user.phone_verified) {
    user = await db.queryOne('UPDATE users SET phone_verified=false, updated_at = NOW() WHERE id = $1 RETURNING *', [user.id]);
  }
  return user;
}

describe('Phone OTP Flow', () => {
  const testPhone = '+94771234567'; // Sri Lankan number for testing custom API
  let sentOtp = null;

  beforeAll(async () => {
    await ensureUser(testPhone);
  });

  afterAll(async () => {
    try { await db.close(); } catch (e) { /* ignore */ }
  });

  test('Send phone OTP stores record', async () => {
    const res = await request(app)
      .post('/api/auth/send-phone-otp')
      .send({ phone: testPhone });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const row = await db.queryOne('SELECT otp FROM phone_otp_verifications WHERE phone = $1 ORDER BY created_at DESC LIMIT 1', [testPhone]);
    expect(row).toBeTruthy();
    sentOtp = row.otp;
    expect(sentOtp).toHaveLength(6);
  }, 15000);

  test('Invalid phone OTP increments attempts', async () => {
    const before = await db.queryOne('SELECT attempts FROM phone_otp_verifications WHERE phone = $1 ORDER BY created_at DESC LIMIT 1', [testPhone]);
    const res = await request(app)
      .post('/api/auth/verify-phone-otp')
      .send({ phone: testPhone, otp: '000000' });
    expect(res.status).toBe(400);
    const after = await db.queryOne('SELECT attempts FROM phone_otp_verifications WHERE phone = $1 ORDER BY created_at DESC LIMIT 1', [testPhone]);
    expect(after.attempts).toBe((before.attempts || 0) + 1);
  }, 15000);

  test('Verify phone OTP succeeds and marks user verified', async () => {
    const res = await request(app)
      .post('/api/auth/verify-phone-otp')
      .send({ phone: testPhone, otp: sentOtp });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.verified).toBe(true);
    expect(res.body.token).toBeTruthy();
    expect(res.body.user).toBeTruthy();
    expect(res.body.provider).toBe('hutch_mobile');
    const user = await db.queryOne('SELECT phone_verified FROM users WHERE phone = $1', [testPhone]);
    expect(user.phone_verified).toBe(true);
  }, 20000);
});
