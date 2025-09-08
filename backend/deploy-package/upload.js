const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();

// Configure multer for image upload
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../uploads/images');
    // Create directory if it doesn't exist
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const ext = path.extname(file.originalname);
    const filename = `${timestamp}_${Math.random().toString(36).substring(2)}${ext}`;
    cb(null, filename);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    const allowedExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif'];
    const ext = path.extname(file.originalname).toLowerCase();
    const isImageMime = file.mimetype && file.mimetype.startsWith('image/');
    const isAllowedExt = allowedExt.includes(ext);
    if (isImageMime || isAllowedExt) {
      if (!isImageMime) {
        console.log('[upload] Accepting file based on extension fallback:', file.originalname, 'mime:', file.mimetype);
      }
      cb(null, true);
    } else {
      console.error('[upload] Rejected file:', file.originalname, 'mime:', file.mimetype);
      cb(new Error('Only image files are allowed'));
    }
  }
});

// Upload multiple product images (expects field name 'files')
router.post('/products', (req, res, next) => {
  // Create a multer instance to accept multiple files under uploads/images
  const multer = require('multer');
  const path = require('path');
  const fs = require('fs');
  const storage = multer.diskStorage({
    destination: (req2, file, cb) => {
      const uploadDir = path.join(__dirname, '../uploads/images');
      if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
      cb(null, uploadDir);
    },
    filename: (req2, file, cb) => {
      const timestamp = Date.now();
      const ext = path.extname(file.originalname);
      cb(null, `product_${timestamp}_${Math.random().toString(36).slice(2)}${ext}`);
    }
  });

  const uploader = multer({ storage });
  uploader.array('files')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    const files = req.files || [];
    if (!files.length) return res.status(400).json({ error: 'No image files provided' });
    const base = `${req.protocol}://${req.get('host')}/uploads/images/`;
    const data = files.map((f) => ({ url: base + f.filename, filename: f.filename, size: f.size }));
    return res.json({ success: true, files: data });
  });
});

// Upload single image (generic images)
router.post('/', upload.single('image'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided' });
    }

    // Generate URL for the uploaded image
    const imageUrl = `${req.protocol}://${req.get('host')}/uploads/images/${req.file.filename}`;
    
    console.log('Image uploaded successfully:', imageUrl);
    
    res.json({
      success: true,
      url: imageUrl,
      filename: req.file.filename,
      size: req.file.size
    });
  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ error: 'Failed to upload image' });
  }
});

// Upload payment method logo (expects field name 'file' from admin UI)
router.post('/payment-methods', (req, res, next) => {
  // Create a multer instance that stores under uploads/images as well
  const multer = require('multer');
  const path = require('path');
  const fs = require('fs');
  const storage = multer.diskStorage({
    destination: (req2, file, cb) => {
      const uploadDir = path.join(__dirname, '../uploads/images');
      if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
      cb(null, uploadDir);
    },
    filename: (req2, file, cb) => {
      const timestamp = Date.now();
      const ext = path.extname(file.originalname);
      cb(null, `pm_${timestamp}_${Math.random().toString(36).slice(2)}${ext}`);
    }
  });
  const uploader = multer({ storage });
  uploader.single('file')(req, res, (err) => {
    if (err) return res.status(400).json({ error: err.message });
    if (!req.file) return res.status(400).json({ error: 'No image file provided' });
    const imageUrl = `${req.protocol}://${req.get('host')}/uploads/images/${req.file.filename}`;
    return res.json({ success: true, url: imageUrl, filename: req.file.filename });
  });
});

// Delete image
router.delete('/', (req, res) => {
  try {
    const { url } = req.body;
    
    if (!url) {
      return res.status(400).json({ error: 'Image URL required' });
    }

    // Extract filename from URL
    const filename = path.basename(url);
    const filePath = path.join(__dirname, '../uploads/images', filename);
    
    // Delete file if it exists
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log('Image deleted:', filename);
    }
    
    res.json({ success: true, message: 'Image deleted successfully' });
  } catch (error) {
    console.error('Error deleting image:', error);
    res.status(500).json({ error: 'Failed to delete image' });
  }
});

module.exports = router;
