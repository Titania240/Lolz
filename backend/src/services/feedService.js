const Meme = require('../models/Meme');
const User = require('../models/User');

// Get feed with pagination and sorting
const getFeed = async (req) => {
  try {
    const {
      sort = 'recent', // 'recent' or 'liked'
      category,
      hashtag,
      offset = 0,
      limit = 20,
    } = req.query;

    // Build query
    const query = {};
    if (category) {
      query.category = category;
    }
    if (hashtag) {
      query.hashtags = hashtag;
    }

    // Build sort
    const sortOptions = {
      recent: { createdAt: -1 },
      liked: { likes: -1 },
    };
    const sortField = sortOptions[sort] || sortOptions.recent;

    // Get total count
    const total = await Meme.countDocuments(query);

    // Get memes
    const memes = await Meme.find(query)
      .sort(sortField)
      .skip(Number(offset))
      .limit(Number(limit))
      .populate('userId', 'name profilePicture');

    return {
      success: true,
      data: {
        memes,
        total,
        offset: Number(offset),
        limit: Number(limit),
      },
    };
  } catch (error) {
    throw error;
  }
};

// Get meme details
const getMemeDetails = async (memeId) => {
  try {
    const meme = await Meme.findById(memeId)
      .populate('userId', 'name profilePicture')
      .populate('comments.userId', 'name profilePicture');

    if (!meme) {
      throw new Error('Meme not found');
    }

    return {
      success: true,
      meme,
    };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  getFeed,
  getMemeDetails,
};
