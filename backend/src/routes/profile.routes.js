const express = require('express');
const router = express.Router();
const { uploadProfilePicture, getProfile, updateProfile } = require('../services/profileService');
const { authMiddleware } = require('../middleware/authMiddleware');
const multer = require('multer');

// Configure multer for file upload
const upload = multer({
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB max
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only images are allowed'));
    }
  },
});

// Get user profile
router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const profile = await getProfile(req.user.id);
    res.json(profile);
  } catch (error) {
    next(error);
  }
});

// Update profile (bio, etc.)
router.patch('/', authMiddleware, async (req, res, next) => {
  try {
    const updates = req.body;
    const result = await updateProfile(req.user.id, updates);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Upload profile picture
router.post('/picture', authMiddleware, upload.single('profilePicture'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }

    const result = await uploadProfilePicture(req.user.id, req.file);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get user stats
router.get('/stats', authMiddleware, async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      throw new Error('User not found');
    }

    res.json({
      success: true,
      stats: {
        uploads: user.uploads,
        likes: user.likes,
        lolCoins: user.lolCoins,
        badge: user.badge,
      },
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
