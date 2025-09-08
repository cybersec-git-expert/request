const db = require('./database');

// Detect existing notifications table schema once and cache
let schemaCache = null;
async function detectSchema() {
  if (schemaCache) return schemaCache;
  const colsRes = await db.query(
    'SELECT column_name FROM information_schema.columns WHERE table_name=\'notifications\''
  );
  const cols = new Set(colsRes.rows.map(r => r.column_name));
  // Legacy schema observed: user_id, body, is_read
  const isLegacy = cols.has('user_id') && cols.has('body') && cols.has('is_read');
  // Newer schema we introduced: recipient_id, message, status
  const isNew = cols.has('recipient_id') && cols.has('message') && cols.has('status');
  schemaCache = {
    isLegacy,
    isNew,
    userIdCol: isLegacy ? 'user_id' : (isNew ? 'recipient_id' : 'user_id'),
    messageCol: isLegacy ? 'body' : (isNew ? 'message' : 'message'),
    readFlagCol: isLegacy ? 'is_read' : (isNew ? 'status' : 'is_read'),
    hasType: cols.has('type'),
    hasSender: cols.has('sender_id'),
  };
  return schemaCache;
}

async function ensureSchema() {
  // Best-effort: make sure at least one UUID extension exists
  try { await db.query('CREATE EXTENSION IF NOT EXISTS pgcrypto'); } catch (_) {}
  try { await db.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'); } catch (_) {}

  // Create table if missing, trying gen_random_uuid(), then uuid_generate_v4(), then no default
  const reg = await db.queryOne('SELECT to_regclass(\'public.notifications\') as tbl');
  if (!reg || !reg.tbl) {
    const commonCols = `
    recipient_id UUID NOT NULL,
    sender_id UUID,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'unread',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ`;

    try {
      await db.query(`CREATE TABLE notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ${commonCols}
      );`);
    } catch (e1) {
      console.warn('notifications.ensureSchema: gen_random_uuid() unavailable, retrying with uuid_generate_v4()', e1.message);
      try {
        await db.query(`CREATE TABLE notifications (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          ${commonCols}
        );`);
      } catch (e2) {
        console.warn('notifications.ensureSchema: uuid_generate_v4() unavailable, creating without default', e2.message);
        await db.query(`CREATE TABLE notifications (
          id UUID PRIMARY KEY,
          ${commonCols}
        );`);
      }
    }
  }

  // Indexes (best-effort, adapt to schema)
  try {
    const sch = await detectSchema();
    if (sch.isLegacy) {
      await db.query('CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at)');
      await db.query('CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read)');
    } else {
      await db.query('CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at DESC);');
      await db.query('CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);');
    }
  } catch (_) {}
}

async function createNotification({ recipientId, senderId, type, title, message, data }) {
  await ensureSchema();
  const sch = await detectSchema();
  if (sch.isLegacy) {
    // Legacy columns: user_id, body, is_read (default false)
    return db.queryOne(
      `INSERT INTO notifications (user_id, type, title, body, data, is_read, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,false,NOW(),NOW()) RETURNING *`,
      [recipientId, type ? String(type) : null, title || '', message || '', data || {}]
    );
  } else {
    // New schema
    return db.queryOne(
      `INSERT INTO notifications (recipient_id, sender_id, type, title, message, data)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [recipientId, senderId || null, String(type), title, message, data ? JSON.stringify(data) : null]
    );
  }
}

async function markAsRead(id) {
  await ensureSchema();
  const sch = await detectSchema();
  if (sch.isLegacy) {
    return db.queryOne('UPDATE notifications SET is_read=true, read_at=NOW(), updated_at=NOW() WHERE id=$1 RETURNING *', [id]);
  }
  // New schema uses status
  return db.queryOne('UPDATE notifications SET status=\'read\', read_at=NOW() WHERE id=$1 RETURNING *', [id]);
}

async function markAllAsRead(userId) {
  await ensureSchema();
  const sch = await detectSchema();
  if (sch.isLegacy) {
    await db.query('UPDATE notifications SET is_read=true, read_at=NOW(), updated_at=NOW() WHERE user_id=$1 AND is_read=false', [userId]);
    return;
  }
  await db.query('UPDATE notifications SET status=\'read\', read_at=NOW() WHERE recipient_id=$1 AND status=\'unread\'', [userId]);
}

async function listForUser(userId, { limit = 200, offset = 0 } = {}) {
  await ensureSchema();
  const sch = await detectSchema();
  const userCol = sch.userIdCol;
  const rows = await db.query(`SELECT * FROM notifications WHERE ${userCol}=$1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`, [userId, limit, offset]);
  return rows.rows;
}

async function countUnread(userId, { type } = {}) {
  await ensureSchema();
  const sch = await detectSchema();
  if (sch.isLegacy) {
    if (type) {
      const row = await db.queryOne(
        'SELECT COUNT(1)::int AS cnt FROM notifications WHERE user_id=$1 AND is_read=false AND type=$2',
        [userId, String(type)]
      );
      return row ? row.cnt : 0;
    }
    const row = await db.queryOne(
      'SELECT COUNT(1)::int AS cnt FROM notifications WHERE user_id=$1 AND is_read=false',
      [userId]
    );
    return row ? row.cnt : 0;
  } else {
    if (type) {
      const row = await db.queryOne(
        'SELECT COUNT(1)::int AS cnt FROM notifications WHERE recipient_id=$1 AND status=\'unread\' AND type=$2',
        [userId, String(type)]
      );
      return row ? row.cnt : 0;
    }
    const row = await db.queryOne(
      'SELECT COUNT(1)::int AS cnt FROM notifications WHERE recipient_id=$1 AND status=\'unread\'',
      [userId]
    );
    return row ? row.cnt : 0;
  }
}

async function remove(id) {
  await ensureSchema();
  return db.queryOne('DELETE FROM notifications WHERE id=$1 RETURNING *', [id]);
}

module.exports = {
  ensureSchema,
  createNotification,
  markAsRead,
  markAllAsRead,
  listForUser,
  countUnread,
  remove,
};
