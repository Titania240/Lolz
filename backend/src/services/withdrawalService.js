const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

class WithdrawalService {
  constructor() {
    this.pool = pool;
  }

  async createWithdrawal(userId, amount, method, paymentInfo) {
    try {
      // Check user eligibility
      const user = await this.pool.query(
        `SELECT id, is_verified, has_badge, lolcoins_earned 
         FROM users 
         WHERE id = $1`,
        [userId]
      );

      if (!user.rows[0]) {
        throw new Error('User not found');
      }

      const { is_verified, has_badge, lolcoins_earned } = user.rows[0];

      // Verify conditions
      if (!is_verified) {
        throw new Error('Account must be verified');
      }

      if (!has_badge) {
        throw new Error('User must have a badge (subscription)');
      }

      if (amount < 2000) {
        throw new Error('Minimum withdrawal amount is 2000 FCFA');
      }

      // Validate minimum and maximum withdrawal amounts
      const minAmount = 2000;
      const maxAmount = 50000; // Maximum withdrawal amount
      const lolcoinsThreshold = lolcoins_earned / 10000;
      const requiredAmount = lolcoinsThreshold * 2000;

      if (amount < minAmount) {
        throw new Error(`Minimum withdrawal amount is ${minAmount} FCFA`);
      }

      if (amount > maxAmount) {
        throw new Error(`Maximum withdrawal amount is ${maxAmount} FCFA`);
      }

      if (amount < requiredAmount) {
        throw new Error(`Insufficient earned lolcoins for withdrawal. You need at least ${requiredAmount} FCFA`);
      }

      // Check last withdrawal date
      const lastWithdrawal = await this.pool.query(
        `SELECT request_date 
         FROM withdrawals 
         WHERE user_id = $1 
         AND status = 'completed' 
         ORDER BY request_date DESC 
         LIMIT 1`,
        [userId]
      );

      if (lastWithdrawal.rows.length > 0) {
        const lastDate = new Date(lastWithdrawal.rows[0].request_date);
        const now = new Date();
        if (now.getMonth() === lastDate.getMonth() && now.getFullYear() === lastDate.getFullYear()) {
          throw new Error('Only one withdrawal per month allowed');
        }
      }

      // Create withdrawal request with transaction
      await this.pool.query('BEGIN');
      try {
        const result = await this.pool.query(
          `INSERT INTO withdrawals (user_id, request_amount, method, payment_info) 
           VALUES ($1, $2, $3, $4) 
           RETURNING *`,
          [userId, amount, method, paymentInfo]
        );

        // Update user's last withdrawal date
        await this.pool.query(
          `UPDATE users 
           SET last_withdrawal_date = NOW() 
           WHERE id = $1`,
          [userId]
        );

        await this.pool.query('COMMIT');
        return result.rows[0];
      } catch (error) {
        await this.pool.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      throw error;
    }
  }

  async getWithdrawalRequests(status = null, userId = null) {
    try {
      let query = `SELECT w.*, u.email as user_email, a.email as admin_email 
                   FROM withdrawals w 
                   LEFT JOIN users u ON w.user_id = u.id 
                   LEFT JOIN users a ON w.admin_id = a.id`;
      
      const params = [];
      const conditions = [];

      if (status) {
        conditions.push('w.status = $${params.length + 1}');
        params.push(status);
      }

      if (userId) {
        conditions.push('w.user_id = $${params.length + 1}');
        params.push(userId);
      }

      if (conditions.length > 0) {
        query += ` WHERE ${conditions.join(' AND ')}`;
      }

      query += ' ORDER BY w.request_date DESC';

      const result = await this.pool.query(query, params);
      return result.rows;
    } catch (error) {
      throw error;
    }
  }

  async updateWithdrawalStatus(withdrawalId, status, adminId, note = null) {
    try {
      await this.pool.query('BEGIN');
      try {
        const result = await this.pool.query(
          `UPDATE withdrawals 
           SET status = $1, 
               admin_id = $2, 
               admin_note = $3, 
               processing_date = NOW()
           WHERE id = $4 
           RETURNING *`,
          [status, adminId, note, withdrawalId]
        );

        // Update user's withdrawal statistics if status is completed
        if (status === 'completed') {
          await this.pool.query(
            `UPDATE users 
             SET total_withdrawn = total_withdrawn + $1 
             WHERE id = (SELECT user_id FROM withdrawals WHERE id = $2)`,
            [result.rows[0].final_amount, withdrawalId]
          );
        }

        await this.pool.query('COMMIT');
        return result.rows[0];
      } catch (error) {
        await this.pool.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      throw error;
    }
  }

  async getUserBalance(userId) {
    try {
      const result = await this.pool.query(
        `SELECT 
            (SELECT COUNT(*) FROM withdrawals 
             WHERE user_id = $1 AND status = 'completed') as completed_withdrawals,
            (SELECT SUM(final_amount) FROM withdrawals 
             WHERE user_id = $1 AND status = 'completed') as total_withdrawn,
            (SELECT lolcoins_earned FROM users WHERE id = $1) as lolcoins_earned`,
        [userId]
      );

      return result.rows[0];
    } catch (error) {
      throw error;
    }
  }

  async getMonthlyWithdrawalLimit(userId) {
    try {
      const result = await this.pool.query(
        `SELECT 
            (SELECT COUNT(*) FROM withdrawals 
             WHERE user_id = $1 
             AND status = 'completed' 
             AND request_date >= date_trunc('month', CURRENT_DATE)) as monthly_count,
            (SELECT lolcoins_earned FROM users WHERE id = $1) as lolcoins_earned`,
        [userId]
      );

      return result.rows[0];
    } catch (error) {
      throw error;
    }
  }
}

module.exports = WithdrawalService;
