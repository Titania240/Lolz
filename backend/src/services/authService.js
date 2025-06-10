const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { google } = require('googleapis');

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN;

// Generate JWT token
const generateToken = (user) => {
  return jwt.sign(
    {
      id: user._id,
      email: user.email,
      role: user.role
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
};

// Register user
const register = async (userData) => {
  const { email, password, name } = userData;
  
  // Check if user exists
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new Error('Email already registered');
  }

  // Create new user
  const user = new User({
    email,
    password,
    name
  });

  await user.save();
  return {
    token: generateToken(user),
    user: {
      id: user._id,
      email: user.email,
      name: user.name,
      role: user.role
    }
  };
};

// Login user
const login = async (email, password) => {
  const user = await User.findOne({ email });
  if (!user) {
    throw new Error('Invalid credentials');
  }

  const isMatch = await user.comparePassword(password);
  if (!isMatch) {
    throw new Error('Invalid credentials');
  }

  return {
    token: generateToken(user),
    user: {
      id: user._id,
      email: user.email,
      name: user.name,
      role: user.role
    }
  };
};

// Google OAuth login
const googleLogin = async (googleId, email, name) => {
  // Check if user exists with Google ID
  let user = await User.findOne({ googleId });
  
  if (!user) {
    // Create new user with Google credentials
    user = new User({
      googleId,
      email,
      name
    });
    await user.save();
  }

  return {
    token: generateToken(user),
    user: {
      id: user._id,
      email: user.email,
      name: user.name,
      role: user.role
    }
  };
};

module.exports = {
  generateToken,
  register,
  login,
  googleLogin
};
