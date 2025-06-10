const AWS = require('aws-sdk');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const Meme = require('../models/Meme');
const User = require('../models/User');

// Configure AWS S3
const s3 = new S3Client({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// Upload limit per badge
const UPLOAD_LIMITS = {
  free: 5,
  bronze: 20,
  silver: 40,
  gold: Infinity,
};

// Validate file type and size
const validateFile = (file) => {
  const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
  if (!allowedTypes.includes(file.mimetype)) {
    throw new Error('Invalid file type. Only JPEG, PNG, and GIF are allowed.');
  }
  if (file.size > 10 * 1024 * 1024) {
    throw new Error('File size exceeds 10MB limit.');
  }
  return true;
};

// Validate hashtags
const validateHashtags = (hashtags) => {
  if (!Array.isArray(hashtags)) {
    throw new Error('Hashtags must be an array');
  }
  if (hashtags.length > 10) {
    throw new Error('Maximum 10 hashtags allowed');
  }
  hashtags.forEach(hashtag => {
    if (typeof hashtag !== 'string') {
      throw new Error('Hashtags must be strings');
    }
    if (hashtag.length > 30) {
      throw new Error('Hashtag cannot exceed 30 characters');
    }
    if (!/^#[a-zA-Z0-9_]+$/.test(hashtag)) {
      throw new Error('Hashtags must start with # and contain only letters, numbers, and underscores');
    }
  });
  return true;
};

// Validate category
const validateCategory = (category) => {
  const allowedCategories = ['funny', 'memes', 'animals', 'food', 'sports', 'other'];
  if (!allowedCategories.includes(category)) {
    throw new Error(`Invalid category. Allowed categories: ${allowedCategories.join(', ')}`);
  }
  return true;
};

// Check daily upload limit
const checkUploadLimit = async (userId) => {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }

  // Get today's date
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Count today's uploads
  const todayUploads = await Meme.countDocuments({
    userId,
    createdAt: {
      $gte: today,
    },
  });

  // Check limit based on badge
  const limit = UPLOAD_LIMITS[user.badge] || UPLOAD_LIMITS.free;
  if (todayUploads >= limit) {
    throw new Error(`Daily upload limit reached (${limit} uploads per day)`);
  }

  return true;
};

// Upload meme to S3
const uploadMeme = async (userId, file, data = {}) => {
  try {
    // Validate file
    validateFile(file);

    // Check upload limit
    await checkUploadLimit(userId);

    // Validate category if provided
    if (data.category) {
      validateCategory(data.category);
    }

    // Validate hashtags if provided
    if (data.hashtags) {
      validateHashtags(data.hashtags);
    }

    // Generate unique filename
    const filename = `memes/${userId}-${Date.now()}-${file.originalname}`;

    // Upload to S3
    const uploadParams = {
      Bucket: process.env.AWS_S3_BUCKET,
      Key: filename,
      Body: file.buffer,
      ContentType: file.mimetype,
      ACL: 'public-read',
    };

    const command = new PutObjectCommand(uploadParams);
    await s3.send(command);

    // Create meme document
    const meme = new Meme({
      title: data.title || file.originalname,
      url: `https://${process.env.AWS_S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${filename}`,
      category: data.category || 'other',
      hashtags: data.hashtags || [],
      userId,
      views: 0,
      likes: 0,
      createdAt: new Date(),
    });

    // Save meme and update user stats
    await meme.save();
    await User.findByIdAndUpdate(userId, {
      $inc: { uploads: 1 },
    });

    return {
      success: true,
      meme,
    };
  } catch (error) {
    throw error;
  }
};

// Create meme from URL
const createMemeFromUrl = async (userId, url, data) => {
  try {
    // Check upload limit
    await checkUploadLimit(userId);

    // Create meme document
    const meme = new Meme({
      ...data,
      url,
      userId,
    });

    // Save meme and update user stats
    await meme.save();
    await User.findByIdAndUpdate(userId, {
      $inc: { uploads: 1 },
    });

    return {
      success: true,
      meme,
    };
  } catch (error) {
    throw error;
  }
};

// Get meme by id
const getMeme = async (id) => {
  try {
    const meme = await Meme.findById(id).populate('userId', 'name profilePicture');
    if (!meme) {
      throw new Error('Meme not found');
    }

    // Increment views
    await Meme.findByIdAndUpdate(id, {
      $inc: { views: 1 },
    });

    return {
      success: true,
      meme,
    };
  } catch (error) {
    throw error;
  }
};

// Like/unlike meme
const toggleLike = async (userId, memeId) => {
  try {
    const meme = await Meme.findById(memeId);
    if (!meme) {
      throw new Error('Meme not found');
    }

    // Update likes
    meme.likes += 1;
    await meme.save();

    // Update user stats
    await User.findByIdAndUpdate(meme.userId, {
      $inc: { likes: 1 },
    });

    return {
      success: true,
      meme,
    };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  uploadMeme,
  createMemeFromUrl,
  getMeme,
  toggleLike,
  getUploadStats: async (userId) => {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayUploads = await Meme.countDocuments({
      userId,
      createdAt: {
        $gte: today,
      },
    });

    return {
      dailyLimit: UPLOAD_LIMITS[user.badge] || UPLOAD_LIMITS.free,
      todayUploads,
      remaining: (UPLOAD_LIMITS[user.badge] || UPLOAD_LIMITS.free) - todayUploads,
    };
  },
};
