const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const axios = require('axios');
const nodemailer = require('nodemailer');
const twilio = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);

// Stripe service
const stripeService = {
  // Create payment intent
  createPaymentIntent: async (amount, currency = 'eur') => {
    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: amount * 100, // Convert to cents
        currency,
      });
      return paymentIntent;
    } catch (error) {
      throw new Error('Failed to create payment intent');
    }
  },

  // Verify payment
  verifyPayment: async (paymentIntentId) => {
    try {
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      return paymentIntent.status === 'succeeded';
    } catch (error) {
      throw new Error('Failed to verify payment');
    }
  },
};

// CinetPay service
const cinetPayService = {
  createPayment: async (amount, currency = 'XOF', phone) => {
    try {
      const response = await axios.post('https://api.cinetpay.com/v2/transaction', {
        apiKey: process.env.CINETPAY_API_KEY,
        site_id: process.env.CINETPAY_SITE_ID,
        amount,
        currency,
        phone,
        return_url: `${process.env.BASE_URL}/payment/success`,
        cancel_url: `${process.env.BASE_URL}/payment/cancel`,
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to create CinetPay payment');
    }
  },

  verifyPayment: async (transactionId) => {
    try {
      const response = await axios.get(`https://api.cinetpay.com/v2/transaction/${transactionId}`);
      return response.data.status === 'success';
    } catch (error) {
      throw new Error('Failed to verify CinetPay payment');
    }
  },
};

// Mobile money services
const mobileMoneyService = {
  // Orange Money withdrawal
  processOrangeMoneyWithdrawal: async (amount, phone) => {
    try {
      const response = await axios.post('https://api.orange-money.com/v1/withdraw', {
        apiKey: process.env.ORANGE_MONEY_API_KEY,
        amount,
        phone,
        description: 'LOLZone withdrawal',
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to process Orange Money withdrawal');
    }
  },

  // MTN Mobile Money withdrawal
  processMTNWithdrawal: async (amount, phone) => {
    try {
      const response = await axios.post('https://api.mtn.com/v1/withdraw', {
        apiKey: process.env.MTN_API_KEY,
        amount,
        phone,
        description: 'LOLZone withdrawal',
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to process MTN withdrawal');
    }
  },

  // Moov withdrawal
  processMoovWithdrawal: async (amount, phone) => {
    try {
      const response = await axios.post('https://api.moov.com/v1/withdraw', {
        apiKey: process.env.MOOV_API_KEY,
        amount,
        phone,
        description: 'LOLZone withdrawal',
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to process Moov withdrawal');
    }
  },
};

// Bank transfer service
const bankTransferService = {
  processBankTransfer: async (amount, iban, bankName, userId) => {
    try {
      // Implementation for bank transfer API
      const response = await axios.post('https://api.banktransfer.com/v1/transfer', {
        apiKey: process.env.BANK_TRANSFER_API_KEY,
        amount,
        iban,
        bankName,
        description: `LOLZone withdrawal for user ${userId}`,
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to process bank transfer');
    }
  },
};

// PayPal service
const paypalService = {
  processPayPalWithdrawal: async (amount, email) => {
    try {
      const response = await axios.post('https://api.paypal.com/v1/payments/payouts', {
        sender_batch_header: {
          sender_batch_id: `PAYOUT-${Date.now()}`,
          email_subject: 'LOLZone Withdrawal',
        },
        items: [
          {
            recipient_type: 'EMAIL',
            amount: {
              value: (amount / 100).toFixed(2), // Convert to euros
              currency: 'EUR',
            },
            note: 'Thank you for using LOLZone!',
            receiver: email,
            sender_item_id: `ITEM-${Date.now()}`,
          },
        ],
      }, {
        headers: {
          'Authorization': `Bearer ${process.env.PAYPAL_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
      });
      return response.data;
    } catch (error) {
      throw new Error('Failed to process PayPal withdrawal');
    }
  },
};

// Notification service
const notificationService = {
  sendEmail: async (to, subject, text) => {
    try {
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASS,
        },
      });

      await transporter.sendMail({
        from: process.env.EMAIL_USER,
        to,
        subject,
        text,
      });
    } catch (error) {
      throw new Error('Failed to send email');
    }
  },

  sendSMS: async (to, message) => {
    try {
      await twilio.messages.create({
        body: message,
        to,
        from: process.env.TWILIO_PHONE_NUMBER,
      });
    } catch (error) {
      throw new Error('Failed to send SMS');
    }
  },
};

module.exports = {
  stripe: stripeService,
  cinetPay: cinetPayService,
  mobileMoney: mobileMoneyService,
  bankTransfer: bankTransferService,
  paypal: paypalService,
  notification: notificationService,
};
