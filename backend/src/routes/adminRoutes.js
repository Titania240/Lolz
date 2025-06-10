const express = require('express');
const router = express.Router();
const { verifyAdmin } = require('../middleware/auth');
const { WithdrawalService } = require('../services/withdrawalService');
const { PaymentService } = require('../services/paymentService');

// Get all withdrawal requests
router.get('/withdrawals', verifyAdmin, async (req, res) => {
  try {
    const withdrawals = await WithdrawalService.getWithdrawalRequests();
    res.json(withdrawals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get withdrawal requests by status
router.get('/withdrawals/status/:status', verifyAdmin, async (req, res) => {
  try {
    const { status } = req.params;
    const withdrawals = await WithdrawalService.getWithdrawalRequests(status);
    res.json(withdrawals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Process withdrawal request
router.post('/withdrawals/:id/process', verifyAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, note } = req.body;
    const withdrawal = await WithdrawalService.getWithdrawalRequests(null, null, id);

    if (!withdrawal) {
      return res.status(404).json({ error: 'Withdrawal not found' });
    }

    // Process payment based on method
    let paymentResult;
    const paymentService = PaymentService;

    switch (withdrawal.method) {
      case 'mobile_money':
        if (withdrawal.payment_info.provider === 'orange') {
          paymentResult = await paymentService.mobileMoney.processOrangeMoneyWithdrawal(
            withdrawal.request_amount,
            withdrawal.payment_info.number
          );
        } else if (withdrawal.payment_info.provider === 'mtn') {
          paymentResult = await paymentService.mobileMoney.processMTNWithdrawal(
            withdrawal.request_amount,
            withdrawal.payment_info.number
          );
        } else if (withdrawal.payment_info.provider === 'moov') {
          paymentResult = await paymentService.mobileMoney.processMoovWithdrawal(
            withdrawal.request_amount,
            withdrawal.payment_info.number
          );
        }
        break;

      case 'bank':
        paymentResult = await paymentService.bankTransfer.processBankTransfer(
          withdrawal.request_amount,
          withdrawal.payment_info.iban,
          withdrawal.payment_info.bank_name,
          withdrawal.user_id
        );
        break;

      case 'paypal':
        paymentResult = await paymentService.paypal.processPayPalWithdrawal(
          withdrawal.request_amount,
          withdrawal.payment_info.email
        );
        break;
    }

    // Update withdrawal status
    await WithdrawalService.updateWithdrawalStatus(id, status, req.user.id, note);

    // Send notification
    await paymentService.notification.sendEmail(
      withdrawal.user_email,
      'Withdrawal Request Processed',
      `Your withdrawal request has been ${status}. ${note ? '\nNote: ' + note : ''}`
    );

    res.json({ success: true, paymentResult });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get withdrawal statistics
router.get('/withdrawals/stats', verifyAdmin, async (req, res) => {
  try {
    const stats = await WithdrawalService.getWithdrawalStats();
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
