const logger = require('winston');

// Gestion des erreurs
const errorHandler = (err, req, res, next) => {
  logger.error('Error:', {
    error: err,
    stack: err.stack,
    message: err.message,
    path: req.path,
    method: req.method,
  });

  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal server error';

  // Ne pas exposer les détails de l'erreur en production
  const errorDetails = process.env.NODE_ENV === 'development' ? err : {};

  res.status(statusCode).json({
    success: false,
    message,
    error: errorDetails,
  });
};

// Gestion des erreurs CSRF
const csrfErrorHandler = (err, req, res, next) => {
  if (err.code === 'EBADCSRFTOKEN') {
    logger.warn('CSRF token invalide');
    return res.status(403).json({
      success: false,
      message: 'CSRF token invalide',
    });
  }
  next(err);
};

// Gestion des erreurs de validation
const validationErrorHandler = (err, req, res, next) => {
  if (err.name === 'ValidationError') {
    logger.warn('Validation error:', err);
    return res.status(400).json({
      success: false,
      message: 'Validation error',
      errors: err.errors,
    });
  }
  next(err);
};

module.exports = {
  errorHandler,
  csrfErrorHandler,
  validationErrorHandler,
};
