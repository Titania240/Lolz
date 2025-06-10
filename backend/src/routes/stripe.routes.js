const express = require('express');
const router = express.Router();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

// Middleware pour vérifier l'authentification
const authMiddleware = require('../middleware/authMiddleware');

// Création d'un PaymentIntent
router.post('/payment', authMiddleware, async (req, res) => {
  try {
    const { amount, currency } = req.body;
    const userId = req.user.id;
    
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      payment_method_types: ['card'],
      metadata: {
        userId: userId,
      },
    });

    res.json({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    console.error('Erreur lors de la création du paiement:', error);
    res.status(500).json({ error: error.message });
  }
});

// Webhook Stripe
router.post('/webhook', express.raw({type: 'application/json'}), async (req, res) => {
  const sig = req.headers['stripe-signature'];

  let event;

  try {
    event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      webhookSecret
    );
  } catch (err) {
    console.error('Erreur de vérification du webhook:', err);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Gérer les différents types d'événements
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      // Mettre à jour la base de données avec le statut du paiement
      await updatePaymentStatus(paymentIntent.id, 'completed');
      break;

    case 'payment_intent.payment_failed':
      const failedIntent = event.data.object;
      // Mettre à jour la base de données avec le statut d'échec
      await updatePaymentStatus(failedIntent.id, 'failed');
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({ received: true });
});

module.exports = router;
