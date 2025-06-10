const mongoose = require('mongoose');

const memeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 100,
  },
  url: {
    type: String,
    required: true,
  },
  category: {
    type: String,
    enum: ['funny', 'dank', 'dark', 'wholesome', 'other'],
    required: true,
  },
  hashtags: [{
    type: String,
    trim: true,
    lowercase: true,
  }],
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  views: {
    type: Number,
    default: 0,
  },
  likes: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

const Meme = mongoose.model('Meme', memeSchema);

module.exports = Meme;
