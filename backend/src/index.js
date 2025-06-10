require('dotenv').config();
const express = require('express');
const { helmet, apiLimiter, cors, xssProtection, csrfProtection } = require('./middleware/securityMiddleware');
const { connectDB } = require('./database');
const { errorHandler, csrfErrorHandler, validationErrorHandler } = require('./middleware/errorHandler');
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const paymentRoutes = require('./routes/payment.routes');
const fileRoutes = require('./routes/file.routes');
const profileRoutes = require('./routes/profile.routes');
const memeRoutes = require('./routes/meme.routes');
const memeEditorRoutes = require('./routes/memeEditor.routes');
const feedRoutes = require('./routes/feed.routes');

// Initialize app
const app = express();

// Security middleware
app.use(helmet);
app.use(cors);
app.use(xssProtection);
app.use(csrfProtection);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
app.use(apiLimiter);

// CSRF protection for API routes
app.use('/api/*', csrfProtection);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/memes', memeRoutes);
app.use('/api/meme-editor', memeEditorRoutes);
app.use('/api/feed', feedRoutes);

// Error handling
app.use(csrfErrorHandler);
app.use(validationErrorHandler);
app.use(errorHandler);

// Connect to database and start server
const startServer = async () => {
  try {
    await connectDB();
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
