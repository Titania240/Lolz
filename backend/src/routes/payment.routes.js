const express = require('express');
const router = express.Router();
const { stripe, cinetPay, mobileMoney } = require('../services/paymentService');
const { authMiddleware } = require('../middleware/authMiddleware');

// Stripe routes
router.post('/stripe/create-payment', authMiddleware, async (req, res, next) => {
  try {
    const { amount, currency } = req.body;
    const paymentIntent = await stripe.createPaymentIntent(amount, currency);
    res.json({
      success: true,
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/stripe/verify-payment', authMiddleware, async (req, res, next) => {
  try {
    const { paymentIntentId } = req.body;
    const isVerified = await stripe.verifyPayment(paymentIntentId);
    res.json({
      success: true,
      verified: isVerified,
    });
  } catch (error) {
    next(error);
  }
});

// CinetPay routes
router.post('/cinetpay/create-payment', authMiddleware, async (req, res, next) => {
  try {
    const { amount, phone } = req.body;
    const payment = await cinetPay.createPayment(amount, 'XOF', phone);
    res.json({
      success: true,
      payment,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/cinetpay/verify-payment', authMiddleware, async (req, res, next) => {
  try {
    const { transactionId } = req.body;
    const isVerified = await cinetPay.verifyPayment(transactionId);
    res.json({
      success: true,
      verified: isVerified,
    });
  } catch (error) {
    next(error);
  }
});

// Mobile Money routes
router.post('/mobile-money/orange', authMiddleware, async (req, res, next) => {
  try {
    const { amount, phone } = req.body;
    const payment = await mobileMoney.createOrangeMoneyPayment(amount, phone);
    res.json({
      success: true,
      payment,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/mobile-money/mtn', authMiddleware, async (req, res, next) => {
  try {
    const { amount, phone } = req.body;
    const payment = await mobileMoney.createMTNPayment(amount, phone);
    res.json({
      success: true,
      payment,
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
