const { check, validationResult } = require('express-validator');

// Validation pour l'inscription
const registerValidation = [
  check('email')
    .isEmail()
    .withMessage('Email invalide')
    .normalizeEmail(),
  check('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères'),
  check('name')
    .trim()
    .notEmpty()
    .withMessage('Le nom est requis'),
];

// Validation pour la connexion
const loginValidation = [
  check('email')
    .isEmail()
    .withMessage('Email invalide')
    .normalizeEmail(),
  check('password')
    .isLength({ min: 6 })
    .withMessage('Le mot de passe doit contenir au moins 6 caractères'),
];

// Middleware de validation
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      errors: errors.array(),
    });
  }
  next();
};

module.exports = {
  registerValidation,
  loginValidation,
  validate,
};
