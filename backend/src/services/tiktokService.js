const { supabase } = require('../config/supabase');

// Weight factors for the algorithm
const WEIGHTS = {
  likes: 0.4,
  comments: 0.3,
  shares: 0.2,
  views: 0.1,
  recency: 0.5,
  user_engagement: 0.3,
  creator_engagement: 0.2,
  badge: 0.1,
  followers: 0.1,
};

// Calculate meme score
const calculateMemeScore = async (meme, userId) => {
  try {
    // Get user engagement metrics
    const { data: userMetrics } = await supabase
      .from('memes')
      .select(`
        likes:likes!meme_id(count),
        comments:comments!meme_id(count),
        shares:shares!meme_id(count),
        views:views!meme_id(count),
        creator:users!user_id(*)
      `)
      .eq('id', meme.id)
      .single();

    if (!userMetrics) return 0;

    // Calculate base score
    const baseScore = (
      userMetrics.likes * WEIGHTS.likes +
      userMetrics.comments * WEIGHTS.comments +
      userMetrics.shares * WEIGHTS.shares +
      userMetrics.views * WEIGHTS.views
    );

    // Calculate recency score
    const recencyScore = WEIGHTS.recency * (1 - (Date.now() - new Date(meme.created_at)) / (24 * 60 * 60 * 1000));

    // Calculate user engagement score
    const userEngagementScore = WEIGHTS.user_engagement * (
      meme.likes?.includes(userId) ? 0.5 : 0 +
      meme.comments?.some(c => c.user_id === userId) ? 0.3 : 0 +
      meme.shares?.includes(userId) ? 0.2 : 0
    );

    // Calculate creator engagement score
    const creatorScore = WEIGHTS.creator_engagement * (
      userMetrics.creator.badge === 'gold' ? 0.5 : 0 +
      userMetrics.creator.badge === 'silver' ? 0.3 : 0 +
      userMetrics.creator.badge === 'bronze' ? 0.2 : 0
    );

    // Calculate followers score
    const followersScore = WEIGHTS.followers * (
      userMetrics.creator.followers_count || 0
    );

    // Final score
    return baseScore + recencyScore + userEngagementScore + creatorScore + followersScore;
  } catch (error) {
    console.error('Error calculating meme score:', error);
    return 0;
  }
};

// Get personalized feed
const getPersonalizedFeed = async (userId, limit = 10) => {
  try {
    // Get memes with user engagement
    const { data: memes, error: memesError } = await supabase
      .from('memes')
      .select(`
        *,
        likes:likes!meme_id(count),
        comments:comments!meme_id(count),
        shares:shares!meme_id(count),
        views:views!meme_id(count),
        creator:users!user_id(*)
      `)
      .order('created_at', { ascending: false })
      .limit(100);

    if (memesError) throw memesError;

    // Calculate scores and sort
    const scoredMemes = await Promise.all(
      memes.map(async (meme) => ({
        ...meme,
        score: await calculateMemeScore(meme, userId)
      }))
    );

    // Sort by score and limit results
    const sortedMemes = scoredMemes
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return sortedMemes;
  } catch (error) {
    throw error;
  }
};

// Get creator profile feed (TikTok-style)
const getCreatorProfileFeed = async (creatorId, userId, limit = 10) => {
  try {
    // Get creator's memes with engagement
    const { data: memes, error: memesError } = await supabase
      .from('memes')
      .select(`
        *,
        likes:likes!meme_id(count),
        comments:comments!meme_id(count),
        shares:shares!meme_id(count),
        views:views!meme_id(count),
        creator:users!user_id(*)
      `)
      .eq('user_id', creatorId)
      .order('created_at', { ascending: false })
      .limit(100);

    if (memesError) throw memesError;

    // Calculate scores and sort
    const scoredMemes = await Promise.all(
      memes.map(async (meme) => ({
        ...meme,
        score: await calculateMemeScore(meme, userId)
      }))
    );

    // Sort by score and limit results
    const sortedMemes = scoredMemes
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return sortedMemes;
  } catch (error) {
    throw error;
  }
};

module.exports = {
  getPersonalizedFeed,
  getCreatorProfileFeed,
};
