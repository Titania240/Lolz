const { supabase } = require('../config/supabase');
const { Stripe } = require('stripe');
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Subscription tiers configuration
const SUBSCRIPTION_TIERS = {
  bronze: {
    price_fcfa: 1500,
    price_eur: 2,
    daily_limit: 20,
    premium_access: 'weekly',
    discount: 0.05,
  },
  silver: {
    price_fcfa: 3500,
    price_eur: 5,
    daily_limit: 40,
    premium_access: '100_lolcoins',
    discount: 0.10,
  },
  gold: {
    price_fcfa: 6000,
    price_eur: 8,
    daily_limit: Infinity,
    premium_access: 'all',
    discount: 0.15,
  },
};

// Get subscription tier details
const getSubscriptionTier = (type) => {
  return SUBSCRIPTION_TIERS[type];
};

// Get user's current subscription
const getCurrentSubscription = async (userId) => {
  try {
    const { data: subscription, error } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true)
      .single();

    if (error) throw error;
    return subscription;
  } catch (error) {
    return null;
  }
};

// Create new subscription
const createSubscription = async (userId, type, paymentMethod, transactionReference) => {
  try {
    const tier = getSubscriptionTier(type);
    if (!tier) throw new Error('Invalid subscription type');

    // Get current subscription
    const currentSubscription = await getCurrentSubscription(userId);

    // If user already has a subscription
    if (currentSubscription) {
      // Extend end date if subscription is active
      const newEndDate = currentSubscription.end_date ? 
        new Date(currentSubscription.end_date).setMonth(
          new Date(currentSubscription.end_date).getMonth() + 1
        ) : 
        new Date().setMonth(new Date().getMonth() + 1);

      const { error } = await supabase
        .from('subscriptions')
        .update({
          end_date: newEndDate,
          payment_method: paymentMethod,
          transaction_reference: transactionReference,
          updated_at: new Date(),
        })
        .eq('id', currentSubscription.id);

      if (error) throw error;
      return { success: true, message: 'Subscription extended successfully' };
    }

    // Create new subscription
    const endDate = new Date();
    endDate.setMonth(endDate.getMonth() + 1);

    const { error: createError } = await supabase
      .from('subscriptions')
      .insert({
        user_id: userId,
        type,
        price_fcfa: tier.price_fcfa,
        price_eur: tier.price_eur,
        end_date: endDate,
        payment_method: paymentMethod,
        transaction_reference: transactionReference,
      });

    if (createError) throw createError;

    return { success: true, message: 'Subscription created successfully' };
  } catch (error) {
    throw error;
  }
};

// Cancel subscription
const cancelSubscription = async (userId) => {
  try {
    const { error } = await supabase
      .from('subscriptions')
      .update({
        is_active: false,
        updated_at: new Date(),
      })
      .eq('user_id', userId)
      .eq('is_active', true);

    if (error) throw error;

    // Update user's badge to 'none'
    const { error: updateError } = await supabase
      .from('users')
      .update({
        badge: 'none',
        updated_at: new Date(),
      })
      .eq('id', userId);

    if (updateError) throw updateError;

    return { success: true, message: 'Subscription cancelled successfully' };
  } catch (error) {
    throw error;
  }
};

// Process Stripe payment
const processStripePayment = async (userId, type, paymentMethod) => {
  try {
    const tier = getSubscriptionTier(type);
    if (!tier) throw new Error('Invalid subscription type');

    // Create payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: tier.price_eur * 100, // Convert to cents
      currency: 'eur',
      automatic_payment_methods: { enabled: true },
    });

    // Create subscription with pending payment
    const { error } = await supabase
      .from('subscriptions')
      .insert({
        user_id: userId,
        type,
        price_eur: tier.price_eur,
        payment_method: paymentMethod,
        transaction_reference: paymentIntent.id,
        is_active: false,
      });

    if (error) throw error;

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
    };
  } catch (error) {
    throw error;
  }
};

// Process CinetPay payment
const processCinetPayPayment = async (userId, type, paymentMethod) => {
  try {
    const tier = getSubscriptionTier(type);
    if (!tier) throw new Error('Invalid subscription type');

    // TODO: Implement CinetPay payment processing
    // This would involve:
    // 1. Creating a payment request with CinetPay API
    // 2. Getting the transaction reference
    // 3. Creating a subscription record
    
    // For now, return a mock response
    return {
      success: true,
      transactionReference: 'CP-' + Date.now(),
    };
  } catch (error) {
    throw error;
  }
};

// Handle payment confirmation webhook
const handlePaymentConfirmation = async (paymentMethod, transactionReference) => {
  try {
    let isValid = false;

    // Verify Stripe payment
    if (paymentMethod === 'stripe') {
      const paymentIntent = await stripe.paymentIntents.retrieve(transactionReference);
      isValid = paymentIntent.status === 'succeeded';
    }
    // TODO: Add CinetPay verification

    if (!isValid) {
      throw new Error('Invalid payment');
    }

    // Activate subscription
    const { error } = await supabase
      .from('subscriptions')
      .update({
        is_active: true,
        updated_at: new Date(),
      })
      .eq('transaction_reference', transactionReference);

    if (error) throw error;

    return { success: true, message: 'Payment confirmed successfully' };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  getSubscriptionTier,
  getCurrentSubscription,
  createSubscription,
  cancelSubscription,
  processStripePayment,
  processCinetPayPayment,
  handlePaymentConfirmation,
};
