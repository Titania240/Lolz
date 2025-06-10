const express = require('express');
const router = express.Router();
const { getFeed, getMemeDetails } = require('../services/feedService');
const { authMiddleware } = require('../middleware/authMiddleware');

// Get feed
router.get('/', async (req, res, next) => {
  try {
    const result = await getFeed(req);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get meme details
router.get('/:id', async (req, res, next) => {
  try {
    const result = await getMemeDetails(req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
