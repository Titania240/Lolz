const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const { getPersonalizedFeed, getCreatorProfileFeed } = require('../services/tiktokService');

// Get personalized feed
router.get('/feed', authMiddleware, async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    const feed = await getPersonalizedFeed(req.user.id, parseInt(limit));
    res.json({ success: true, data: feed });
  } catch (error) {
    next(error);
  }
});

// Get creator profile feed
router.get('/profile/:creatorId', authMiddleware, async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    const feed = await getCreatorProfileFeed(req.params.creatorId, req.user.id, parseInt(limit));
    res.json({ success: true, data: feed });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
