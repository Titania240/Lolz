const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const { 
  getSubscriptionTier,
  getCurrentSubscription,
  createSubscription,
  cancelSubscription,
  processStripePayment,
  processCinetPayPayment,
  handlePaymentConfirmation 
} = require('../services/subscriptionService');

// Get subscription tiers
router.get('/tiers', async (req, res, next) => {
  try {
    res.json({
      success: true,
      tiers: {
        bronze: {
          price_fcfa: 1500,
          price_eur: 2,
          benefits: [
            '20 memes/day',
            'Access to free premium memes',
            'Bronze badge',
            '5% discount on LOLCoins'
          ]
        },
        silver: {
          price_fcfa: 3500,
          price_eur: 5,
          benefits: [
            '40 memes/day',
            'Access to premium memes ≤ 100 LOLCoins',
            'Silver badge',
            '10% discount on LOLCoins',
            'Contest participation'
          ]
        },
        gold: {
          price_fcfa: 6000,
          price_eur: 8,
          benefits: [
            'Unlimited memes',
            'All premium memes free',
            'Gold badge',
            '15% discount on LOLCoins',
            'Premium contests',
            'Advanced features'
          ]
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

// Get user's subscription status
router.get('/status', authMiddleware, async (req, res, next) => {
  try {
    const subscription = await getCurrentSubscription(req.user.id);
    res.json({
      success: true,
      subscription: subscription || {
        type: 'none',
        is_active: false,
        end_date: null,
      }
    });
  } catch (error) {
    next(error);
  }
});

// Subscribe
router.post('/subscribe', authMiddleware, async (req, res, next) => {
  try {
    const { type, paymentMethod } = req.body;
    
    if (paymentMethod === 'stripe') {
      const result = await processStripePayment(req.user.id, type, paymentMethod);
      res.json(result);
    } else {
      const result = await processCinetPayPayment(req.user.id, type, paymentMethod);
      res.json(result);
    }
  } catch (error) {
    next(error);
  }
});

// Cancel subscription
router.post('/cancel', authMiddleware, async (req, res, next) => {
  try {
    const result = await cancelSubscription(req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Payment confirmation webhook
router.post('/webhook/payment-confirmation', async (req, res, next) => {
  try {
    const { paymentMethod, transactionReference } = req.body;
    const result = await handlePaymentConfirmation(paymentMethod, transactionReference);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
