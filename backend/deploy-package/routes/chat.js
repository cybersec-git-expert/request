// Clean, corrected copy aligned with runtime chat route
const express = require('express');
const router = express.Router();
const db = require('../services/database');
const notify = require('../services/notification-helper');
const { randomUUID } = require('crypto');

async function ensureSchema() {
  try { await db.query('CREATE EXTENSION IF NOT EXISTS pgcrypto'); } catch (_) {}
  try { await db.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'); } catch (_) {}
  try {
    await db.query(`CREATE TABLE IF NOT EXISTS conversations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      request_id UUID NOT NULL,
      participant_a UUID,
      participant_b UUID,
      participant_ids UUID[],
      last_message_text TEXT,
      last_message_at TIMESTAMPTZ DEFAULT NOW(),
      created_at TIMESTAMPTZ DEFAULT NOW()
    );`);
  } catch (e1) {
    try {
      await db.query(`CREATE TABLE IF NOT EXISTS conversations (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        request_id UUID NOT NULL,
        participant_a UUID,
        participant_b UUID,
        participant_ids UUID[],
        last_message_text TEXT,
        last_message_at TIMESTAMPTZ DEFAULT NOW(),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );`);
    } catch (e2) {
      await db.query(`CREATE TABLE IF NOT EXISTS conversations (
        id UUID PRIMARY KEY,
        request_id UUID NOT NULL,
        participant_a UUID,
        participant_b UUID,
        participant_ids UUID[],
        last_message_text TEXT,
        last_message_at TIMESTAMPTZ DEFAULT NOW(),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );`);
    }
  }
  await db.query('ALTER TABLE conversations ADD COLUMN IF NOT EXISTS participant_a UUID;');
  await db.query('ALTER TABLE conversations ADD COLUMN IF NOT EXISTS participant_b UUID;');
  await db.query('ALTER TABLE conversations ADD COLUMN IF NOT EXISTS created_by UUID;');
  await db.query('ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_text TEXT;');
  await db.query('ALTER TABLE conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ;');
  await db.query(`UPDATE conversations SET participant_a = participant_ids[1], participant_b = participant_ids[2]
                  WHERE participant_a IS NULL AND participant_ids IS NOT NULL AND array_length(participant_ids,1)=2;`);
  await db.query('UPDATE conversations SET created_by = COALESCE(participant_a, participant_ids[1]) WHERE created_by IS NULL;');
  await db.query(`DO $$ BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'conversations_request_participants_key'
    ) THEN
      ALTER TABLE conversations
        ADD CONSTRAINT conversations_request_participants_key UNIQUE (request_id, participant_a, participant_b);
    END IF;
  END $$;`);
  try {
    await db.query(`CREATE TABLE IF NOT EXISTS messages (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL,
      content TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );`);
  } catch (e1) {
    try {
      await db.query(`CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
        sender_id UUID NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );`);
    } catch (e2) {
      await db.query(`CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY,
        conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
        sender_id UUID NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );`);
    }
  }
}

function canonicalPair(a, b) { return a < b ? [a, b] : [b, a]; }

router.post('/open', async (req, res) => {
  try {
    const { requestId, currentUserId, otherUserId } = req.body;
    if (!requestId || !currentUserId || !otherUserId) {
      return res.status(400).json({ success: false, error: 'requestId, currentUserId, otherUserId required' });
    }
    await ensureSchema();
    const [a, b] = canonicalPair(currentUserId, otherUserId);
    let convo = await db.queryOne('SELECT * FROM conversations WHERE request_id=$1 AND participant_a=$2 AND participant_b=$3', [requestId, a, b]);
    if (!convo) {
      convo = await db.queryOne('SELECT * FROM conversations WHERE request_id=$1 AND participant_a IS NULL AND participant_ids @> ARRAY[$2,$3]::uuid[] AND array_length(participant_ids,1)=2', [requestId, a, b]);
    }
    if (!convo) {
      const newId = randomUUID();
      convo = await db.queryOne('INSERT INTO conversations (id, request_id, participant_a, participant_b, participant_ids, created_by) VALUES ($1,$2,$3,$4, ARRAY[$3,$4]::uuid[], $5) RETURNING *', [newId, requestId, a, b, currentUserId]);
    } else if (!convo.participant_a) {
      try {
        await db.query('UPDATE conversations SET participant_a=$1, participant_b=$2 WHERE id=$3', [a, b, convo.id]);
        convo.participant_a = a; convo.participant_b = b;
      } catch (_) {}
    }
    const messages = await db.query('SELECT * FROM messages WHERE conversation_id=$1 ORDER BY created_at ASC LIMIT 100', [convo.id]);
    const requestRow = await db.queryOne('SELECT title FROM requests WHERE id=$1', [requestId]);
    res.json({ success: true, conversation: { ...convo, requestTitle: requestRow?.title }, messages: messages.rows });
  } catch (e) {
    console.error('Chat open error', e);
    res.status(500).json({ success: false, error: 'Failed to open conversation' });
  }
});

router.get('/conversations', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ success: false, error: 'userId required' });
    await ensureSchema();
    const rows = await db.query(`
      SELECT c.*, r.title AS request_title
      FROM conversations c
      JOIN requests r ON r.id = c.request_id
      WHERE (
        c.participant_a = $1::uuid OR c.participant_b = $1::uuid OR
        (c.participant_a IS NULL AND c.participant_ids @> ARRAY[$1::uuid])
      )
      ORDER BY c.last_message_at DESC
      LIMIT 200
    `, [userId]);
    res.json({ success: true, conversations: rows.rows });
  } catch (e) {
    console.error('Chat list error', e);
    res.status(500).json({ success: false, error: 'Failed to list conversations' });
  }
});

router.get('/messages/:conversationId', async (req, res) => {
  try {
    const { conversationId } = req.params;
    const rows = await db.query('SELECT * FROM messages WHERE conversation_id=$1 ORDER BY created_at ASC LIMIT 500', [conversationId]);
    res.json({ success: true, messages: rows.rows });
  } catch (e) {
    console.error('Chat messages error', e);
    res.status(500).json({ success: false, error: 'Failed to fetch messages' });
  }
});

router.post('/messages', async (req, res) => {
  try {
    const { conversationId, senderId, content } = req.body;
    if (!conversationId || !senderId || !content) {
      return res.status(400).json({ success: false, error: 'conversationId, senderId, content required' });
    }
    const convo = await db.queryOne('SELECT * FROM conversations WHERE id=$1', [conversationId]);
    if (!convo) return res.status(404).json({ success: false, error: 'Conversation not found' });
    const msgId = randomUUID();
    const msg = await db.queryOne('INSERT INTO messages (id, conversation_id, sender_id, content) VALUES ($1,$2,$3,$4) RETURNING *', [msgId, conversationId, senderId, content]);
    await db.query('UPDATE conversations SET last_message_text=$1, last_message_at=NOW() WHERE id=$2', [content.substring(0, 500), conversationId]);
    try {
      const otherId = (convo.participant_a === senderId) ? convo.participant_b : convo.participant_a;
      if (otherId) {
        await notify.createNotification({
          recipientId: otherId,
          senderId,
          type: 'newMessage',
          title: 'New message',
          message: content.substring(0, 120),
          data: { conversationId, requestId: convo.request_id }
        });
      }
    } catch (e) { console.warn('notify newMessage failed', e?.message || e); }
    res.json({ success: true, message: msg });
  } catch (e) {
    console.error('Chat send error', e);
    res.status(500).json({ success: false, error: 'Failed to send message' });
  }
});

module.exports = router;
 
