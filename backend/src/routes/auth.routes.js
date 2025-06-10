const express = require('express');
const router = express.Router();
const { register, login, googleLogin } = require('../services/authService');
const { authMiddleware } = require('../middleware/authMiddleware');

// Register
router.post('/register', async (req, res, next) => {
  try {
    const result = await register(req.body);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

// Login
router.post('/login', async (req, res, next) => {
  try {
    const result = await login(req.body.email, req.body.password);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Google OAuth callback
router.get('/google/callback', async (req, res, next) => {
  try {
    const { code } = req.query;
    if (!code) {
      throw new Error('No authorization code provided');
    }

    // Exchange code for Google tokens
    const { tokens } = await google.auth.oAuth2Client.getToken(code);
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_CALLBACK_URL
    );
    oauth2Client.setCredentials(tokens);

    // Get user info
    const { data } = await oauth2Client.request({
      url: 'https://www.googleapis.com/oauth2/v3/userinfo'
    });

    const result = await googleLogin(data.sub, data.email, data.name);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Protected route example
router.get('/protected', authMiddleware, (req, res) => {
  res.json({
    message: 'Protected route accessed successfully',
    user: req.user
  });
});

module.exports = router;
