const Comment = require('../models/Comment');
const Share = require('../models/Share');
const User = require('../models/User');

// Like/unlike meme
const toggleLike = async (userId, memeId) => {
  try {
    const meme = await Meme.findById(memeId);
    if (!meme) {
      throw new Error('Meme not found');
    }

    // Toggle like
    if (meme.likes.includes(userId)) {
      meme.likes.pull(userId);
      await meme.save();

      // Update user stats
      await User.findByIdAndUpdate(userId, {
        $inc: { totalLikes: -1 },
      });

      // Update meme creator's stats
      await User.findByIdAndUpdate(meme.userId, {
        $inc: { receivedLikes: -1 },
      });

      return {
        success: true,
        message: 'Meme unliked',
        likes: meme.likes.length,
      };
    } else {
      meme.likes.push(userId);
      await meme.save();

      // Update user stats
      await User.findByIdAndUpdate(userId, {
        $inc: { totalLikes: 1 },
      });

      // Update meme creator's stats
      await User.findByIdAndUpdate(meme.userId, {
        $inc: { receivedLikes: 1 },
      });

      // Calculate LOLCoins (100 likes = 5 LOLCoins)
      const currentLikes = meme.likes.length;
      const creator = await User.findById(meme.userId);
      const newCoins = Math.floor(currentLikes / 100) * 5;
      
      if (newCoins > 0 && creator.lolcoins < newCoins) {
        await User.findByIdAndUpdate(meme.userId, {
          $inc: { lolcoins: newCoins - creator.lolcoins },
        });
      }

      return {
        success: true,
        message: 'Meme liked',
        likes: meme.likes.length,
      };
    }
  } catch (error) {
    throw error;
  }
};

// Add comment
const addComment = async (userId, memeId, content) => {
  try {
    const meme = await Meme.findById(memeId);
    if (!meme) {
      throw new Error('Meme not found');
    }

    const comment = new Comment({
      memeId,
      userId,
      content,
      createdAt: new Date(),
    });

    await comment.save();
    meme.comments.push(comment._id);
    await meme.save();

    // Increment comment count for user
    await User.findByIdAndUpdate(userId, {
      $inc: { totalComments: 1 },
    });

    return {
      success: true,
      comment,
    };
  } catch (error) {
    throw error;
  }
};

// Get comments
const getComments = async (memeId, page = 1, limit = 10) => {
  try {
    const skip = (page - 1) * limit;
    const comments = await Comment.find({ memeId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('userId', 'name profilePicture');

    const total = await Comment.countDocuments({ memeId });

    return {
      success: true,
      comments,
      totalPages: Math.ceil(total / limit),
      currentPage: page,
    };
  } catch (error) {
    throw error;
  }
};

// Log share
const logShare = async (userId, memeId, platform) => {
  try {
    const meme = await Meme.findById(memeId);
    if (!meme) {
      throw new Error('Meme not found');
    }

    const share = new Share({
      memeId,
      userId,
      platform,
      createdAt: new Date(),
    });

    await share.save();
    meme.shares.push(share._id);
    await meme.save();

    // Increment share count for user
    await User.findByIdAndUpdate(userId, {
      $inc: { totalShares: 1 },
    });

    return {
      success: true,
      share,
    };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  toggleLike,
  addComment,
  getComments,
  logShare,
};
