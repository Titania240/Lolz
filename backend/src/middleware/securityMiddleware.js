const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

// Configuration de Helmet
const helmetConfig = {
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
  crossOriginOpenerPolicy: false,
};

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
});

// CORS configuration
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS.split(','),
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};

// XSS protection
const xssFilter = require('x-xss-protection');
const xssProtection = xssFilter({
  value: '1; mode=block',
});

// CSRF protection
const csrf = require('csurf');
const csrfProtection = csrf({ cookie: true });

module.exports = {
  helmet: helmet(helmetConfig),
  apiLimiter,
  cors: cors(corsOptions),
  xssProtection,
  csrfProtection,
};
