const { WithdrawalService } = require('../src/services/withdrawalService');
const { Pool } = require('pg');
const assert = require('assert');
const sinon = require('sinon');

// Configuration de test pour les services de paiement
const TEST_CONFIG = {
  // Mobile Money
  ORANGE_MONEY_API_KEY: 'test-orange-money-key',
  MTN_API_KEY: 'test-mtn-key',
  MOOV_API_KEY: 'test-moov-key',
  WAVE_API_KEY: 'test-wave-key',

  // PayPal
  PAYPAL_CLIENT_ID: 'test-paypal-client-id',
  PAYPAL_CLIENT_SECRET: 'test-paypal-client-secret',
  PAYPAL_ACCESS_TOKEN: 'test-paypal-access-token',

  // Bank Transfer
  BANK_TRANSFER_API_KEY: 'test-bank-transfer-key',
  BANK_TRANSFER_SECRET: 'test-bank-transfer-secret',

  // Database
  DB_NAME: 'test_db',
  DB_USER: 'test_user',
  DB_PASSWORD: 'test_password',
  DB_HOST: 'localhost',
  DB_PORT: 5432,
};

describe('WithdrawalService', () => {
  let withdrawalService;
  let pool;
  let sandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
    pool = new Pool({
      connectionString: `postgresql://${TEST_CONFIG.DB_USER}:${TEST_CONFIG.DB_PASSWORD}@${TEST_CONFIG.DB_HOST}:${TEST_CONFIG.DB_PORT}/${TEST_CONFIG.DB_NAME}`,
    });
    withdrawalService = new WithdrawalService();
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('createWithdrawal', () => {
    it('should create a new withdrawal request', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [{
          id: '123-456-789',
          user_id: 'user-123',
          request_amount: 5000,
          method: 'mobile_money',
          status: 'pending',
          request_date: '2025-06-06',
        }],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      const result = await withdrawalService.createWithdrawal(
        'user-123',
        5000,
        'mobile_money',
        { number: '0700000000', provider: 'orange' }
      );

      assert.strictEqual(result.status, 'pending');
      assert.strictEqual(result.request_amount, 5000);
    });

    it('should throw error if user is not verified', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [{ is_verified: false }],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      await assert.rejects(
        withdrawalService.createWithdrawal(
          'user-123',
          5000,
          'mobile_money',
          { number: '0700000000', provider: 'orange' }
        ),
        { message: 'Account must be verified' }
      );
    });

    it('should throw error if monthly limit is reached', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [{ monthly_count: 1 }],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      await assert.rejects(
        withdrawalService.createWithdrawal(
          'user-123',
          5000,
          'mobile_money',
          { number: '0700000000', provider: 'orange' }
        ),
        { message: 'Only one withdrawal per month allowed' }
      );
    });
  });

  describe('getWithdrawalRequests', () => {
    it('should get all withdrawal requests', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [
          {
            id: '123-456-789',
            user_id: 'user-123',
            request_amount: 5000,
            method: 'mobile_money',
            status: 'pending',
            request_date: '2025-06-06',
          },
        ],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      const result = await withdrawalService.getWithdrawalRequests();
      assert.strictEqual(result.length, 1);
    });

    it('should get withdrawal requests by status', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [
          {
            id: '123-456-789',
            user_id: 'user-123',
            request_amount: 5000,
            method: 'mobile_money',
            status: 'pending',
            request_date: '2025-06-06',
          },
        ],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      const result = await withdrawalService.getWithdrawalRequests('pending');
      assert.strictEqual(result[0].status, 'pending');
    });
  });

  describe('updateWithdrawalStatus', () => {
    it('should update withdrawal status to completed', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [{
          id: '123-456-789',
          status: 'completed',
          admin_id: 'admin-123',
          processing_date: '2025-06-06',
        }],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      const result = await withdrawalService.updateWithdrawalStatus(
        '123-456-789',
        'completed',
        'admin-123',
        'Withdrawal processed successfully'
      );

      assert.strictEqual(result.status, 'completed');
    });

    it('should update withdrawal status to refused with note', async () => {
      const mockQuery = sandbox.stub().resolves({
        rows: [{
          id: '123-456-789',
          status: 'refused',
          admin_id: 'admin-123',
          admin_note: 'Insufficient funds',
          processing_date: '2025-06-06',
        }],
      });

      sandbox.stub(pool, 'query').callsFake(mockQuery);

      const result = await withdrawalService.updateWithdrawalStatus(
        '123-456-789',
        'refused',
        'admin-123',
        'Insufficient funds'
      );

      assert.strictEqual(result.status, 'refused');
      assert.strictEqual(result.admin_note, 'Insufficient funds');
    });
  });

  describe('processPayment', () => {
    it('should process Orange Money withdrawal', async () => {
      const mockPayment = sandbox.stub().resolves({
        status: 'success',
        transaction_id: 'OM-123456',
      });

      sandbox.stub(withdrawalService.paymentService.mobileMoney, 'processOrangeMoneyWithdrawal').callsFake(mockPayment);

      const result = await withdrawalService.processPayment(
        5000,
        'mobile_money',
        { number: '0700000000', provider: 'orange' }
      );

      assert.strictEqual(result.status, 'success');
    });

    it('should process PayPal withdrawal', async () => {
      const mockPayment = sandbox.stub().resolves({
        status: 'success',
        payout_batch_id: 'PAYOUT-123456',
      });

      sandbox.stub(withdrawalService.paymentService.paypal, 'processPayPalWithdrawal').callsFake(mockPayment);

      const result = await withdrawalService.processPayment(
        5000,
        'paypal',
        { email: 'user@example.com' }
      );

      assert.strictEqual(result.status, 'success');
    });
  });

  describe('sendNotification', () => {
    it('should send email notification', async () => {
      const mockSendEmail = sandbox.stub().resolves();

      sandbox.stub(withdrawalService.notificationService, 'sendEmail').callsFake(mockSendEmail);

      await withdrawalService.sendNotification(
        'user@example.com',
        'Withdrawal Processed',
        'Your withdrawal has been processed successfully'
      );

      assert(mockSendEmail.calledOnce);
    });

    it('should send SMS notification', async () => {
      const mockSendSMS = sandbox.stub().resolves();

      sandbox.stub(withdrawalService.notificationService, 'sendSMS').callsFake(mockSendSMS);

      await withdrawalService.sendNotification(
        '+2250700000000',
        'Withdrawal Processed',
        'Your withdrawal has been processed successfully'
      );

      assert(mockSendSMS.calledOnce);
    });
  });
});
