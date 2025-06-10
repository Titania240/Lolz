const express = require('express');
const router = express.Router();
const { uploadMeme, createMemeFromUrl, getMeme, getUploadStats } = require('../services/memeService');
const { toggleLike, addComment, getComments, logShare } = require('../services/memeInteractionService');
const { authMiddleware } = require('../middleware/authMiddleware');
const multer = require('multer');

// Configure multer for file upload
const upload = multer({
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only images are allowed'));
    }
  },
});

// Upload meme (image file)
router.post('/', authMiddleware, upload.single('meme'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded',
      });
    }

    const result = await uploadMeme(req.user.id, req.file);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Create meme from URL
router.post('/url', authMiddleware, async (req, res, next) => {
  try {
    const { url, title, category, hashtags } = req.body;
    
    if (!url) {
      return res.status(400).json({
        success: false,
        message: 'URL is required',
      });
    }

    const result = await createMemeFromUrl(req.user.id, url, {
      title,
      category,
      hashtags,
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get meme by id
router.get('/:id', async (req, res, next) => {
  try {
    const result = await getMeme(req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Like/unlike meme
router.post('/:id/like', authMiddleware, async (req, res, next) => {
  try {
    const result = await toggleLike(req.user.id, req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Add comment to meme
router.post('/:id/comments', authMiddleware, async (req, res, next) => {
  try {
    const { content } = req.body;
    if (!content) {
      return res.status(400).json({
        success: false,
        message: 'Content is required',
      });
    }

    const result = await addComment(req.user.id, req.params.id, content);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get meme comments
router.get('/:id/comments', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;

    const result = await getComments(req.params.id, page, limit);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Log meme share
router.post('/:id/share', authMiddleware, async (req, res, next) => {
  try {
    const { platform } = req.body;
    if (!platform) {
      return res.status(400).json({
        success: false,
        message: 'Platform is required',
      });
    }

    const result = await logShare(req.user.id, req.params.id, platform);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get upload statistics
router.get('/stats', authMiddleware, async (req, res, next) => {
  try {
    const stats = await getUploadStats(req.user.id);
    res.json({
      success: true,
      stats,
    });
  } catch (error) {
    next(error);
  }
});

// Get trending memes
router.get('/trending', async (req, res, next) => {
  try {
    const memes = await Meme.find()
      .sort({ likes: -1 })
      .limit(50)
      .populate('userId', 'name profilePicture');

    res.json({
      success: true,
      memes,
    });
  } catch (error) {
    next(error);
  }
});

// Get memes by category
router.get('/category/:category', async (req, res, next) => {
  try {
    const memes = await Meme.find({ category: req.params.category })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate('userId', 'name profilePicture');

    res.json({
      success: true,
      memes,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
