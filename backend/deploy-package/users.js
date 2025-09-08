const express = require('express');
const router = express.Router();
const auth = require('../services/auth');
const database = require('../services/database');

// Test endpoint
router.get('/test', (req, res) => {
  res.json({
    success: true,
    message: 'Users route is working!',
    timestamp: new Date().toISOString()
  });
});

// Update user profile
router.put('/:userId', auth.authMiddleware(), async (req, res) => {
  try {
    const { userId } = req.params;
    const updateData = req.body;

    // Verify the user can only update their own profile (unless admin)
    if (req.user.id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Unauthorized to update this profile'
      });
    }

    // Build dynamic query based on provided fields
    const allowedFields = [
      'first_name', 'last_name', 'phone', 'email', 
      'display_name', 'date_of_birth', 'gender'
    ];
    
    const updateFields = [];
    const updateValues = [];
    let paramIndex = 1;

    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key) && updateData[key] !== undefined) {
        updateFields.push(`${key} = $${paramIndex}`);
        updateValues.push(updateData[key]);
        paramIndex++;
      }
    });

    if (updateFields.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No valid fields to update'
      });
    }

    // Add updated_at timestamp
    updateFields.push('updated_at = NOW()');

    // Execute update query
    const query = `
      UPDATE users 
      SET ${updateFields.join(', ')} 
      WHERE id = $${paramIndex} 
      RETURNING *
    `;
    updateValues.push(userId);

    console.log('🔄 Updating user profile:', {
      userId,
      fields: updateFields,
      values: updateValues
    });

    const result = await database.query(query, updateValues);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const updatedUser = result.rows[0];
    
    // Remove sensitive fields from response
    delete updatedUser.password_hash;
    delete updatedUser.firebase_uid;

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedUser
    });

  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update profile'
    });
  }
});

// Get user profile
router.get('/:userId', auth.authMiddleware(), async (req, res) => {
  try {
    const { userId } = req.params;

    // Verify the user can only access their own profile (unless admin)
    if (req.user.id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Unauthorized to access this profile'
      });
    }

    const result = await database.query(
      'SELECT * FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const user = result.rows[0];
    
    // Remove sensitive fields from response
    delete user.password_hash;
    delete user.firebase_uid;

    res.json({
      success: true,
      data: user
    });

  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch profile'
    });
  }
});

module.exports = router;
