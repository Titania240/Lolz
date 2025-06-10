const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  googleId: {
    type: String,
    unique: true,
    sparse: true
  },
  name: {
    type: String,
    required: true,
    trim: true
  },
  avatar: {
    type: String,
    default: ''
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user'
  },
  profilePicture: {
    type: String,
    default: null
  },
  bio: {
    type: String,
    default: '',
    maxlength: 200
  },
  lolCoins: {
    type: Number,
    default: 0
  },
  uploads: {
    type: Number,
    default: 0
  },
  likes: {
    type: Number,
    default: 0
  },
  badge: {
    type: String,
    enum: ['bronze', 'silver', 'gold', 'platinum'],
    default: 'bronze'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare password
userSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Method to update stats
userSchema.methods.updateStats = async function({ uploads = 0, likes = 0 }) {
  this.uploads += uploads;
  this.likes += likes;
  
  // Update badge based on stats
  if (this.uploads >= 100 && this.likes >= 500) {
    this.badge = 'platinum';
  } else if (this.uploads >= 50 && this.likes >= 200) {
    this.badge = 'gold';
  } else if (this.uploads >= 20 && this.likes >= 100) {
    this.badge = 'silver';
  } else if (this.uploads >= 5 && this.likes >= 20) {
    this.badge = 'bronze';
  }
};

const User = mongoose.model('User', userSchema);
module.exports = User;
