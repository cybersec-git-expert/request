const { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand, ListBucketsCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl: presignGet } = require('@aws-sdk/s3-request-presigner');
const multer = require('multer');
const path = require('path');

// Configure AWS SDK v3 client
const REGION = process.env.AWS_REGION || process.env.AWS_S3_REGION || 'us-east-1';
const s3Client = new S3Client({
  region: REGION,
  // Use default credential provider chain (IAM role, ECS/EC2 IMDS, env, shared config)
  // Do NOT pass static credentials here; production should use an IAM role
});

// S3 bucket configuration
const BUCKET_NAME =
  process.env.AWS_S3_BUCKET ||
  process.env.S3_BUCKET_NAME ||
  process.env.S3_BUCKET ||
  'requestappbucket';

// Configure multer for memory storage (we'll handle S3 upload manually)
const uploadToMemory = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    console.log('📁 File upload attempt:', {
      originalname: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname
    });
    
    const allowedMimes = [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp',
      'image/bmp',
      'image/heic',
      'image/heif',
      'application/pdf',
      'application/octet-stream' // Sometimes mobile uploads use this
    ];
    
    const allowedExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif', '.pdf'];
    const ext = path.extname(file.originalname).toLowerCase();
    
    // Accept if either MIME type is allowed OR extension is allowed
    const isMimeAllowed = allowedMimes.includes(file.mimetype);
    const isExtAllowed = allowedExts.includes(ext);
    const isImageMime = file.mimetype && file.mimetype.startsWith('image/');
    
    if (isMimeAllowed || isExtAllowed || isImageMime) {
      console.log('✅ File accepted:', file.originalname);
      cb(null, true);
    } else {
      console.log('❌ File rejected:', {
        filename: file.originalname,
        mimetype: file.mimetype,
        extension: ext
      });
      cb(new Error(`Invalid file type: ${file.mimetype}. Only images and PDFs are allowed.`));
    }
  }
});

// Helper to construct a public-style URL (even if object is private) for consistent storage
function buildObjectUrl(bucket, key) {
  const safeKey = encodeURI(key).replace(/%5B/g, '[').replace(/%5D/g, ']').replace(/%2F/g, '/');
  if (REGION === 'us-east-1') {
    return `https://${bucket}.s3.amazonaws.com/${safeKey}`;
  }
  return `https://${bucket}.s3.${REGION}.amazonaws.com/${safeKey}`;
}

function extractKeyFromUrl(fileUrl, bucketName) {
  try {
    const url = new URL(fileUrl);
    const host = url.hostname; // e.g., bucket.s3.region.amazonaws.com or s3.amazonaws.com
    const path = url.pathname; // e.g., /key or /bucket/key
    if (host.startsWith(`${bucketName}.`)) {
      // Virtual-hosted-style: bucket in subdomain, key in path
      return decodeURIComponent(path.replace(/^\//, ''));
    }
    // Path-style: host doesn't include bucket, path starts with /bucket/
    const prefix = `/${bucketName}/`;
    if (path.startsWith(prefix)) {
      return decodeURIComponent(path.substring(prefix.length));
    }
    // Fallback to previous naive approach
    return fileUrl.split('/').slice(3).join('/');
  } catch (_) {
    return fileUrl.split('/').slice(3).join('/');
  }
}

// Manual S3 upload function
const uploadToS3 = async (file, uploadType, userId, imageIndex) => {
  const timestamp = Date.now();
  const ext = path.extname(file.originalname);
  const randomString = Math.random().toString(36).substring(2);
  
  let keyPath;
  switch (uploadType) {
  case 'driver_photo':
    keyPath = `drivers/${userId}/driver_photo_${timestamp}.jpg`;
    break;
  case 'nic_front':
    keyPath = `drivers/${userId}/nic_front_${timestamp}.jpg`;
    break;
  case 'nic_back':
    keyPath = `drivers/${userId}/nic_back_${timestamp}.jpg`;
    break;
  case 'license_front':
    keyPath = `drivers/${userId}/license_front_${timestamp}.jpg`;
    break;
  case 'license_back':
    keyPath = `drivers/${userId}/license_back_${timestamp}.jpg`;
    break;
  case 'license_document':
    keyPath = `drivers/${userId}/license_document_${timestamp}${ext}`;
    break;
  case 'vehicle_registration':
    keyPath = `drivers/${userId}/vehicle_registration_${timestamp}${ext}`;
    break;
  case 'insurance_document':
    keyPath = `drivers/${userId}/insurance_document_${timestamp}${ext}`;
    break;
  case 'billing_proof':
    keyPath = `drivers/${userId}/billing_proof_${timestamp}${ext}`;
    break;
  case 'vehicle_image':
    const imgIndex = imageIndex || '1';
    keyPath = `vehicles/${userId}/${imgIndex}_${timestamp}.jpg`;
    break;
  case 'about-us':
    // Public company assets used in content pages
    keyPath = `public/about/logo_${timestamp}_${randomString}${ext || '.png'}`;
    break;
  case 'master-products':
    // Centralized master product images (do not depend on userId)
    keyPath = `public/master-products/file_${timestamp}_${randomString}${ext || '.jpg'}`;
    break;
  default:
    // Fallback path; ensure we don't write to 'undefined'
    keyPath = `uploads/${userId || 'public'}/${file.fieldname || 'file'}_${timestamp}_${randomString}${ext || '.bin'}`;
  }

  const params = {
    Bucket: BUCKET_NAME,
    Key: keyPath,
    Body: file.buffer,
    ContentType: file.mimetype,
  };

  try {
    console.log('🚀 Uploading to S3 (v3):', keyPath);
    await s3Client.send(new PutObjectCommand(params));
    const location = buildObjectUrl(BUCKET_NAME, keyPath);
    console.log('✅ S3 upload successful:', location);
    return location;
  } catch (error) {
    console.error('❌ S3 upload failed:', error);
    throw error;
  }
};

// Helper function to delete file from S3
const deleteFromS3 = async (fileUrl) => {
  try {
    const key = extractKeyFromUrl(fileUrl, BUCKET_NAME);
    const params = { Bucket: BUCKET_NAME, Key: key };
    await s3Client.send(new DeleteObjectCommand(params));
    console.log('✅ File deleted from S3:', key);
    return true;
  } catch (error) {
    console.error('❌ Error deleting file from S3:', error);
    throw error;
  }
};

// Helper function to generate pre-signed URL for viewing
const getSignedUrl = async (fileUrl, expiresIn = 3600) => {
  try {
    const key = extractKeyFromUrl(fileUrl, BUCKET_NAME);
    const command = new GetObjectCommand({ Bucket: BUCKET_NAME, Key: key });
    const signedUrl = await presignGet(s3Client, command, { expiresIn });
    console.log('✅ Generated signed URL for:', key);
    return signedUrl;
  } catch (error) {
    console.error('❌ Error generating signed URL:', error);
    throw error;
  }
};

// Simple connectivity test used by the /api/s3/test route
async function testS3Connection() {
  const result = await s3Client.send(new ListBucketsCommand({}));
  return { buckets: result.Buckets || [] };
}

module.exports = {
  uploadToMemory,
  uploadToS3,
  deleteFromS3,
  getSignedUrl,
  testS3Connection,
  // Export client for advanced callers (avoid using raw client in routes)
  s3Client,
};
