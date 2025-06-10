const express = require('express');
const router = express.Router();
const { authMiddleware } = require('../middleware/authMiddleware');
const { 
  createPremiumMeme, 
  purchasePremiumMeme, 
  purchaseUploadPack, 
  purchaseLOLCoins 
} = require('../services/premiumService');

// Premium memes routes
router.post('/memes/premium', authMiddleware, async (req, res, next) => {
  try {
    const { data, error } = await createPremiumMeme(req.user.id, req.body);
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

router.post('/memes/:id/purchase', authMiddleware, async (req, res, next) => {
  try {
    const { success, message } = await purchasePremiumMeme(req.user.id, req.params.id);
    res.json({ success, message });
  } catch (error) {
    next(error);
  }
});

// Upload packs routes
router.get('/upload-packs', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('upload_packs')
      .select('*');
    
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

router.post('/upload-packs/:id/purchase', authMiddleware, async (req, res, next) => {
  try {
    const { success, message } = await purchaseUploadPack(req.user.id, req.params.id);
    res.json({ success, message });
  } catch (error) {
    next(error);
  }
});

// LOLCoins routes
router.get('/lolcoins/packs', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('lolcoin_packs')
      .select('*')
      .eq('is_active', true);
    
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

router.post('/lolcoins/packs/:id/purchase', authMiddleware, async (req, res, next) => {
  try {
    const { paymentProvider } = req.body;
    const { success, message } = await purchaseLOLCoins(
      req.user.id,
      req.params.id,
      paymentProvider
    );
    res.json({ success, message });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
