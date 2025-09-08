const express = require('express');
const router = express.Router();
const db = require('../services/database');
const { randomUUID } = require('crypto');

function canonicalPair(a, b) { 
  return a < b ? [a, b] : [b, a]; 
}

router.get('/conversations', async (req, res) => {
  try {
    const { userId } = req.query;
    if (!userId) {
      return res.status(400).json({ success: false, error: 'userId required' });
    }
    
    // Simple query without complex JOINs to avoid permission issues
    const rows = await db.query(`
      SELECT c.*, 'Request' as request_title
      FROM conversations c
      WHERE (
        c.participant_a = $1::uuid OR 
        c.participant_b = $1::uuid OR
        (c.participant_a IS NULL AND c.participant_ids @> ARRAY[$1::uuid])
      )
      ORDER BY c.last_message_at DESC NULLS LAST
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
    const rows = await db.query(
      'SELECT * FROM messages WHERE conversation_id=$1 ORDER BY created_at ASC LIMIT 500', 
      [conversationId]
    );
    res.json({ success: true, messages: rows.rows });
  } catch (e) {
    console.error('Chat messages error', e);
    res.status(500).json({ success: false, error: 'Failed to fetch messages' });
  }
});

router.post('/open', async (req, res) => {
  try {
    const { requestId, currentUserId, otherUserId } = req.body;
    if (!requestId || !currentUserId || !otherUserId) {
      return res.status(400).json({ 
        success: false, 
        error: 'requestId, currentUserId, otherUserId required' 
      });
    }
    
    const [a, b] = canonicalPair(currentUserId, otherUserId);
    
    // Try to find existing conversation
    let convo = await db.queryOne(
      'SELECT * FROM conversations WHERE request_id=$1 AND participant_a=$2 AND participant_b=$3', 
      [requestId, a, b]
    );
    
    if (!convo) {
      // Create new conversation
      const newId = randomUUID();
      convo = await db.queryOne(`
        INSERT INTO conversations (id, request_id, participant_a, participant_b, participant_ids, created_by) 
        VALUES ($1, $2, $3, $4, ARRAY[$3,$4]::uuid[], $5) 
        RETURNING *
      `, [newId, requestId, a, b, currentUserId]);
    }
    
    const messages = await db.query(
      'SELECT * FROM messages WHERE conversation_id=$1 ORDER BY created_at ASC LIMIT 100', 
      [convo.id]
    );
    
    res.json({ 
      success: true, 
      conversation: { ...convo, requestTitle: 'Request' }, 
      messages: messages.rows 
    });
  } catch (e) {
    console.error('Chat open error', e);
    res.status(500).json({ success: false, error: 'Failed to open conversation' });
  }
});

router.post('/messages', async (req, res) => {
  try {
    const { conversationId, senderId, content } = req.body;
    if (!conversationId || !senderId || !content) {
      return res.status(400).json({ 
        success: false, 
        error: 'conversationId, senderId, content required' 
      });
    }
    
    const convo = await db.queryOne('SELECT * FROM conversations WHERE id=$1', [conversationId]);
    if (!convo) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }
    
    // Insert message
    const msgId = randomUUID();
    const msg = await db.queryOne(`
      INSERT INTO messages (id, conversation_id, sender_id, content) 
      VALUES ($1, $2, $3, $4) 
      RETURNING *
    `, [msgId, conversationId, senderId, content]);
    
    // Update conversation
    await db.query(
      'UPDATE conversations SET last_message_text=$1, last_message_at=NOW() WHERE id=$2', 
      [content.substring(0, 500), conversationId]
    );
    
    res.json({ success: true, message: msg });
  } catch (e) {
    console.error('Chat send error', e);
    res.status(500).json({ success: false, error: 'Failed to send message' });
  }
});

module.exports = router;
