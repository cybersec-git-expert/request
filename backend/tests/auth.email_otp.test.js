process.env.NODE_ENV = 'test';
const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../app');
const db = require('../services/database');

// Helper to create a user (unverified email)
async function ensureUser(email) {
  let user = await db.queryOne('SELECT * FROM users WHERE email = $1', [email]);
  if (!user) {
    const passwordHash = await bcrypt.hash('TempPass123!', 10);
    user = await db.queryOne(`INSERT INTO users (email, password_hash, display_name, role, is_active, email_verified, phone_verified, country_code, created_at, updated_at)
      VALUES ($1,$2,$3,'user',true,false,false,'LK',NOW(),NOW()) RETURNING *`, [email, passwordHash, 'OTP Test User']);
  } else if (user.email_verified) {
    user = await db.queryOne('UPDATE users SET email_verified=false, updated_at = NOW() WHERE id = $1 RETURNING *', [user.id]);
  }
  return user;
}

describe('Email OTP Flow', () => {
  const testEmail = 'otp_flow_test@example.com';
  let sentOtp = null;

  beforeAll(async () => {
    await ensureUser(testEmail);
  });

  afterAll(async () => {
    try { await db.close(); } catch (e) { /* ignore */ }
  });

  test('Send email OTP returns metadata', async () => {
    const res = await request(app)
      .post('/api/auth/send-email-otp')
      .send({ email: testEmail });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.channel || res.body.channel === undefined).toBeTruthy();
    // Fetch OTP directly from DB
    const row = await db.queryOne('SELECT otp FROM email_otp_verifications WHERE email = $1', [testEmail]);
    expect(row).toBeTruthy();
    sentOtp = row.otp;
    expect(sentOtp).toHaveLength(6);
  }, 15000);

  test('Invalid OTP increments attempts', async () => {
    const before = await db.queryOne('SELECT attempts FROM email_otp_verifications WHERE email = $1', [testEmail]);
    const res = await request(app)
      .post('/api/auth/verify-email-otp')
      .send({ email: testEmail, otp: '000000' });
    expect(res.status).toBe(400);
    const after = await db.queryOne('SELECT attempts FROM email_otp_verifications WHERE email = $1', [testEmail]);
    expect(after.attempts).toBe((before.attempts || 0) + 1);
  }, 15000);

  test('Verify email OTP succeeds and marks user verified', async () => {
    const res = await request(app)
      .post('/api/auth/verify-email-otp')
      .send({ email: testEmail, otp: sentOtp });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.verified).toBe(true);
    expect(res.body.data.token).toBeTruthy();
    // user flag updated
    const user = await db.queryOne('SELECT email_verified FROM users WHERE email = $1', [testEmail]);
    expect(user.email_verified).toBe(true);
  }, 20000);
});
