const AWS = require('aws-sdk');
const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const User = require('../models/User');

// Configure AWS S3
const s3 = new S3Client({
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// Upload profile picture to S3
const uploadProfilePicture = async (userId, file) => {
  try {
    // Generate unique filename
    const filename = `profile-pictures/${userId}-${Date.now()}-${file.originalname}`;
    
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

    // Update user profile
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    user.profilePicture = `https://${process.env.AWS_S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${filename}`;
    await user.save();

    return {
      success: true,
      profilePicture: user.profilePicture,
    };
  } catch (error) {
    throw new Error('Failed to upload profile picture');
  }
};

// Get user profile
const getProfile = async (userId) => {
  try {
    const user = await User.findById(userId).select('-password');
    if (!user) {
      throw new Error('User not found');
    }

    return {
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        profilePicture: user.profilePicture,
        bio: user.bio,
        lolCoins: user.lolCoins,
        uploads: user.uploads,
        likes: user.likes,
        badge: user.badge,
        createdAt: user.createdAt,
      },
    };
  } catch (error) {
    throw new Error('Failed to get user profile');
  }
};

// Update user profile
const updateProfile = async (userId, updates) => {
  try {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Update bio if provided
    if (updates.bio !== undefined) {
      user.bio = updates.bio;
    }

    // Update stats if provided
    if (updates.uploads !== undefined || updates.likes !== undefined) {
      await user.updateStats(updates);
    }

    await user.save();

    return {
      success: true,
      message: 'Profile updated successfully',
    };
  } catch (error) {
    throw new Error('Failed to update profile');
  }
};

module.exports = {
  uploadProfilePicture,
  getProfile,
  updateProfile,
};
