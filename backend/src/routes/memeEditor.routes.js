const express = require('express');
const router = express.Router();
const multer = require('multer');
const { authMiddleware } = require('../middleware/authMiddleware');
const { uploadUserImage, getGalleryImages, purchasePremiumImage, createMeme, importImages, updateImageStatus } = require('../services/memeEditorService');

// Configure multer for file upload
const upload = multer({
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB max
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype === 'video/mp4') {
      cb(null, true);
    } else {
      cb(new Error('Only images and videos are allowed'));
    }
  }
});

// User routes
router.post('/upload', authMiddleware, upload.single('file'), async (req, res, next) => {
  try {
    const result = await uploadUserImage(req.user.id, req.file, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/gallery', async (req, res, next) => {
  try {
    const { category, type, limit } = req.query;
    const result = await getGalleryImages(category, type, limit);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.post('/premium/:imageId/purchase', authMiddleware, async (req, res, next) => {
  try {
    const result = await purchasePremiumImage(req.user.id, req.params.imageId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.post('/create', authMiddleware, async (req, res, next) => {
  try {
    const result = await createMeme(req.user.id, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Admin routes
router.post('/admin/import', authMiddleware, upload.array('files', 10), async (req, res, next) => {
  try {
    const results = await importImages(req.user.id, req.files, req.body);
    res.json(results);
  } catch (error) {
    next(error);
  }
});

router.patch('/admin/image/:imageId/status', authMiddleware, async (req, res, next) => {
  try {
    const result = await updateImageStatus(req.user.id, req.params.imageId, req.body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
