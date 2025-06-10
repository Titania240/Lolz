const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const { 
  getActiveChallenges,
  createChallenge,
  approveChallenge,
  rejectChallenge,
  participateInChallenge,
  getChallengeResults,
  reportChallengeParticipation
} = require('../services/challengeService');

// Middleware to check admin role
const isAdmin = async (req, res, next) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('role')
      .eq('id', req.user.id)
      .single();

    if (error) throw error;
    if (!user || user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Admin access required'
      });
    }
    next();
  } catch (error) {
    next(error);
  }
};

// Get active challenges
router.get('/active', async (req, res, next) => {
  try {
    const challenges = await getActiveChallenges();
    res.json({ success: true, data: challenges });
  } catch (error) {
    next(error);
  }
});

// Create new challenge (Gold subscribers only)
router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const challenge = await createChallenge(req.user.id, req.body);
    res.json({ success: true, data: challenge });
  } catch (error) {
    next(error);
  }
});

// Approve challenge (admin only)
router.post('/:id/approve', [authMiddleware, isAdmin], async (req, res, next) => {
  try {
    const result = await approveChallenge(req.params.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Reject challenge (admin only)
router.post('/:id/reject', [authMiddleware, isAdmin], async (req, res, next) => {
  try {
    const { reason } = req.body;
    const result = await rejectChallenge(req.params.id, reason);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get user notifications
router.get('/notifications', authMiddleware, async (req, res, next) => {
  try {
    const { data: notifications, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', req.user.id)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json({ success: true, data: notifications });
  } catch (error) {
    next(error);
  }
});

// Mark notification as read
router.post('/notifications/:id/read', authMiddleware, async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ read: true })
      .eq('id', req.params.id)
      .eq('user_id', req.user.id);

    if (error) throw error;
    res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    next(error);
  }
});

// Get weekly challenges
router.get('/weekly', async (req, res, next) => {
  try {
    const { data: challenges, error } = await supabase
      .from('challenges')
      .select('*')
      .eq('status', 'active')
      .eq('type', 'automatic')
      .order('start_date', { ascending: false });

    if (error) throw error;
    res.json({ success: true, data: challenges });
  } catch (error) {
    next(error);
  }
});

// Participate in challenge
router.post('/:id/participate', authMiddleware, async (req, res, next) => {
  try {
    const { memeId } = req.body;
    const result = await participateInChallenge(req.user.id, req.params.id, memeId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// Get challenge results
router.get('/:id/results', async (req, res, next) => {
  try {
    const results = await getChallengeResults(req.params.id);
    res.json({ success: true, data: results });
  } catch (error) {
    next(error);
  }
});

// Report challenge participation
router.post('/:id/participations/:participationId/report', authMiddleware, async (req, res, next) => {
  try {
    const { reason } = req.body;
    const result = await reportChallengeParticipation(req.user.id, req.params.participationId, reason);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
