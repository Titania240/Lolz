const { supabase } = require('../config/supabase');
const { checkUploadLimit } = require('./memeService');

// Premium meme functions
const createPremiumMeme = async (userId, memeData) => {
  try {
    const { price_lolcoins, ...memeDataWithoutPrice } = memeData;
    
    // Validate price
    if (!price_lolcoins || price_lolcoins < 50) {
      throw new Error('Premium meme price must be at least 50 LOLCoins');
    }

    // Validate user's subscription
    const { data: subscription, error: subscriptionError } = await supabase
      .from('subscriptions')
      .select('type')
      .eq('user_id', userId)
      .eq('is_active', true)
      .single();

    if (subscriptionError) throw subscriptionError;
    
    // Only gold users can create premium memes
    if (subscription?.type !== 'gold') {
      throw new Error('Only Gold subscribers can create premium memes');
    }

    // Create meme with is_premium = true
    const { data: meme, error: memeError } = await supabase
      .from('memes')
      .insert({
        ...memeDataWithoutPrice,
        user_id: userId,
        is_premium: true,
        price_lolcoins,
      })
      .select()
      .single();

    if (memeError) throw memeError;

    return meme;
  } catch (error) {
    throw error;
  }
};

const purchasePremiumMeme = async (userId, memeId) => {
  try {
    // Get meme details
    const { data: meme, error: memeError } = await supabase
      .from('memes')
      .select('price_lolcoins, user_id')
      .eq('id', memeId)
      .eq('is_premium', true)
      .single();

    if (memeError) throw memeError;
    if (!meme) throw new Error('Premium meme not found');

    // Check if already purchased
    const { data: existingPurchase, error: checkPurchaseError } = await supabase
      .from('meme_purchases')
      .select('id')
      .eq('user_id', userId)
      .eq('meme_id', memeId)
      .single();

    if (checkPurchaseError && checkPurchaseError.code !== 'PGRST116') {
      throw checkPurchaseError;
    }

    if (existingPurchase) {
      throw new Error('Meme already purchased');
    }

    // Check user's subscription
    const { data: subscription, error: subscriptionError } = await supabase
      .from('subscriptions')
      .select('type')
      .eq('user_id', userId)
      .eq('is_active', true)
      .single();

    if (subscriptionError) throw subscriptionError;
    
    // Get user's earned LOLCoins
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('lolcoins_earned')
      .eq('id', userId)
      .single();

    if (userError) throw userError;
    if (!user) throw new Error('User not found');

    // Check if user has enough earned LOLCoins
    if (user.lolcoins_earned < meme.price_lolcoins) {
      throw new Error('Insufficient earned LOLCoins');
    }

    // Start transaction
    const { error: transactionError } = await supabase
      .from('transactions')
      .insert({
        user_id: userId,
        type: 'premium_purchase',
        amount: meme.price_lolcoins,
        status: 'pending',
        created_at: new Date(),
      });

    if (transactionError) throw transactionError;

    // Deduct LOLCoins
    const { error: updateError } = await supabase
      .from('users')
      .update({
        lolcoins_earned: supabase.ref('lolcoins_earned').sub(meme.price_lolcoins),
      })
      .eq('id', userId);

    if (updateError) throw updateError;

    // Create purchase record
    const { error: createPurchaseError } = await supabase
      .from('meme_purchases')
      .insert({
        user_id: userId,
        meme_id: memeId,
        price_lolcoins: meme.price_lolcoins,
      });

    if (purchaseError) throw purchaseError;

    // Calculate creator's earnings (70%)
    const creatorEarnings = Math.floor(meme.price_lolcoins * 0.7);
    const platformEarnings = meme.price_lolcoins - creatorEarnings;

    // Update creator's earnings
    const { error: creatorError } = await supabase
      .from('users')
      .update({
        lolcoins_earned: supabase.ref('lolcoins_earned').add(creatorEarnings),
      })
      .eq('id', meme.user_id);

    if (creatorError) throw creatorError;

    // Update platform earnings
    const { error: platformError } = await supabase
      .from('users')
      .update({
        lolcoins_earned: supabase.ref('lolcoins_earned').add(platformEarnings),
      })
      .eq('id', userId);

    if (platformError) throw platformError;

    // Update transaction status
    const { error: updateTransactionError } = await supabase
      .from('transactions')
      .update({
        status: 'completed',
        completed_at: new Date(),
      })
      .eq('user_id', userId)
      .eq('type', 'premium_purchase')
      .eq('status', 'pending');

    if (updateTransactionError) throw updateTransactionError;

    return { success: true, message: 'Meme purchased successfully' };
  } catch (error) {
    // If error occurs, rollback transaction
    await supabase
      .from('transactions')
      .update({
        status: 'failed',
        error_message: error.message,
      })
      .eq('user_id', userId)
      .eq('type', 'premium_purchase')
      .eq('status', 'pending');

    throw error;
  }
};

// Upload pack functions
const purchaseUploadPack = async (userId, packId) => {
  try {
    // Get pack details
    const { data: pack, error: packError } = await supabase
      .from('upload_packs')
      .select('extra_uploads, price_lolcoins')
      .eq('id', packId)
      .single();

    if (packError) throw packError;
    if (!pack) throw new Error('Upload pack not found');

    // Check user's subscription
    const { data: subscription, error: subscriptionError } = await supabase
      .from('subscriptions')
      .select('type')
      .eq('user_id', userId)
      .eq('is_active', true)
      .single();

    if (subscriptionError) throw subscriptionError;
    
    // Get user's purchased LOLCoins
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('lolcoins_purchased')
      .eq('id', userId)
      .single();

    if (userError) throw userError;
    if (!user) throw new Error('User not found');

    // Check if user has enough purchased LOLCoins
    if (user.lolcoins_purchased < pack.price_lolcoins) {
      throw new Error('Insufficient purchased LOLCoins');
    }

    // Start transaction
    const { error: transactionError } = await supabase
      .from('transactions')
      .insert({
        user_id: userId,
        type: 'upload_pack_purchase',
        amount: pack.price_lolcoins,
        status: 'pending',
        created_at: new Date(),
      });

    if (transactionError) throw transactionError;

    // Create purchase record
    const { error: purchaseError } = await supabase
      .from('upload_pack_purchases')
      .insert({
        user_id: userId,
        upload_pack_id: packId,
      });

    if (purchaseError) throw purchaseError;

    // Deduct LOLCoins
    const { error: updateError } = await supabase
      .from('users')
      .update({
        lolcoins_purchased: supabase.ref('lolcoins_purchased').sub(pack.price_lolcoins),
      })
      .eq('id', userId);

    if (updateError) throw updateError;

    // Create transaction record
    const { error: transactionRecordError } = await supabase
      .from('lolcoin_transactions')
      .insert({
        user_id: userId,
        type: 'used',
        amount: pack.price_lolcoins,
        description: 'Purchased upload pack',
      });

    if (transactionRecordError) throw transactionRecordError;

    // Update transaction status
    const { error: updateTransactionError } = await supabase
      .from('transactions')
      .update({
        status: 'completed',
        completed_at: new Date(),
      })
      .eq('user_id', userId)
      .eq('type', 'upload_pack_purchase')
      .eq('status', 'pending');

    if (updateTransactionError) throw updateTransactionError;

    return { success: true, message: 'Upload pack purchased successfully' };
  } catch (error) {
    // If error occurs, rollback transaction
    await supabase
      .from('transactions')
      .update({
        status: 'failed',
        error_message: error.message,
      })
      .eq('user_id', userId)
      .eq('type', 'upload_pack_purchase')
      .eq('status', 'pending');

    throw error;
  }
};

// LOLCoins functions
const purchaseLOLCoins = async (userId, packId, paymentProvider, region) => {
  try {
    // Get pack details
    const { data: pack, error: packError } = await supabase
      .from('lolcoin_packs')
      .select('*')
      .eq('id', packId)
      .eq('is_active', true)
      .single();

    if (packError) throw packError;
    if (!pack) throw new Error('LOLCoins pack not found');

    // Get payment amount based on region
    let amount;
    if (region === 'africa') {
      amount = pack.price_fcfa;
    } else {
      amount = pack.price_eur;
    }

    // Start transaction
    const { error: transactionError } = await supabase
      .from('transactions')
      .insert({
        user_id: userId,
        type: 'lolcoins_purchase',
        amount,
        payment_method: paymentProvider,
        status: 'pending',
        created_at: new Date(),
      });

    if (transactionError) throw transactionError;

    // Create payment record
    const { error: paymentError } = await supabase
      .from('payments')
      .insert({
        user_id: userId,
        method: paymentProvider,
        amount,
        status: 'pending',
        description: `Purchased ${pack.amount_lolcoins} LOLCoins`,
      });

    if (paymentError) throw paymentError;

    return {
      success: true,
      message: 'Payment initiated successfully',
      transaction_id: transactionError?.data?.id,
      amount,
      currency: region === 'africa' ? 'FCFA' : 'EUR',
    };
  } catch (error) {
    // If error occurs, rollback transaction
    await supabase
      .from('transactions')
      .update({
        status: 'failed',
        error_message: error.message,
      })
      .eq('user_id', userId)
      .eq('type', 'lolcoins_purchase')
      .eq('status', 'pending');

    throw error;
  }
};

module.exports = {
  createPremiumMeme,
  purchasePremiumMeme,
  purchaseUploadPack,
  purchaseLOLCoins,
};
