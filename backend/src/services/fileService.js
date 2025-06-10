const AWS = require('aws-sdk');
const multer = require('multer');
const multerS3 = require('multer-s3');

// Configuration AWS
AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});

const s3 = new AWS.S3();

// Configuration Multer
const upload = multer({
  storage: multerS3({
    s3: s3,
    bucket: process.env.AWS_S3_BUCKET,
    acl: 'public-read',
    metadata: (req, file, cb) => {
      cb(null, { fieldName: file.fieldname });
    },
    key: (req, file, cb) => {
      const fileName = `${Date.now()}-${file.originalname}`;
      cb(null, fileName);
    },
  }),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
      cb(null, true);
    } else {
      cb(new Error('Only images and videos are allowed'));
    }
  },
});

// Upload unique file
const uploadFile = upload.single('file');

// Upload multiple files
const uploadFiles = upload.array('files', 5); // Max 5 files

// Get file from S3
const getFile = async (key) => {
  try {
    const params = {
      Bucket: process.env.AWS_S3_BUCKET,
      Key: key,
    };
    return await s3.getObject(params).promise();
  } catch (error) {
    throw new Error('File not found');
  }
};

// Delete file from S3
const deleteFile = async (key) => {
  try {
    const params = {
      Bucket: process.env.AWS_S3_BUCKET,
      Key: key,
    };
    await s3.deleteObject(params).promise();
  } catch (error) {
    throw new Error('Failed to delete file');
  }
};

// Get file URL
const getFileUrl = (key) => {
  return `https://${process.env.AWS_S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${key}`;
};

module.exports = {
  uploadFile,
  uploadFiles,
  getFile,
  deleteFile,
  getFileUrl,
};
