const jwt = require('jsonwebtoken');
const User = require('../models/User');

const verifyToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id);
    if (!req.user) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

const verifyAdmin = async (req, res, next) => {
  try {
    await verifyToken(req, res, () => {});
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Admin access required' });
    }
    next();
  } catch (error) {
    res.status(403).json({ error: 'Admin access required' });
  }
};

module.exports = {
  verifyToken,
  verifyAdmin,
};
