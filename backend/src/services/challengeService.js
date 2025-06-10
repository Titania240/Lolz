const { supabase } = require('../config/supabase');

const cron = require('node-cron');

// Configuration des cron jobs
const CRON_CONFIG = {
  generateWeeklyChallenges: '0 0 * * 1',  // Lundi à 00:00
  processChallengeResults: '0 * * * *',   // Toutes les heures
  sendChallengeReminders: '0 * * * *'    // Toutes les heures
};

// Configuration des notifications
const NOTIFICATION_TYPES = {
  CHALLENGE_SUBMITTED: 'challenge_submitted',
  CHALLENGE_APPROVED: 'challenge_approved',
  CHALLENGE_REJECTED: 'challenge_rejected',
  CHALLENGE_REMINDER: 'challenge_reminder',
  CHALLENGE_WON: 'challenge_won'
};

// Configuration des récompenses
const CHALLENGE_REWARDS = {
  FIRST_PLACE: 2000,
  SECOND_PLACE: 1000,
  THIRD_PLACE: 500,
  PARTICIPANT: 50
};

// Configuration des statuts
const CHALLENGE_STATUSES = {
  PENDING: 'pending',
  ACTIVE: 'active',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled'
};

// Configuration des types de challenges
const CHALLENGE_TYPES = {
  AUTOMATIC: 'automatic',
  USER_SUBMITTED: 'user_submitted'
};

// Configuration des badges
const BADGES = {
  GOLD: 'gold',
  SILVER: 'silver',
  BRONZE: 'bronze'
};

// Initialisation des jobs cron
const generateWeeklyChallenges = cron.schedule(CRON_CONFIG.generateWeeklyChallenges, async () => {
  try {
    // Générer les challenges hebdomadaires
    const { error: generateError } = await supabase.rpc('generate_weekly_challenges');
    if (generateError) {
      console.error('Erreur lors de la génération des challenges hebdomadaires:', generateError);
      return;
    }

    // Créer les challenges à partir des générations
    const { error: createError } = await supabase.rpc('create_challenge_from_generation');
    if (createError) {
      console.error('Erreur lors de la création des challenges:', createError);
      return;
    }

    console.log('Challenges hebdomadaires générés avec succès');
  } catch (error) {
    console.error('Erreur générale lors de la génération des challenges:', error);
  }
});

// Traitement des résultats des challenges
const processChallengeResults = cron.schedule(CRON_CONFIG.processChallengeResults, async () => {
  try {
    const { error } = await supabase.rpc('process_challenge_results');
    if (error) {
      console.error('Erreur lors du traitement des résultats des challenges:', error);
      return;
    }
    console.log('Résultats des challenges traités avec succès');
  } catch (error) {
    console.error('Erreur générale lors du traitement des résultats:', error);
  }
});

// Envoi des rappels pour les challenges
const sendChallengeReminders = cron.schedule(CRON_CONFIG.sendChallengeReminders, async () => {
  try {
    const { error } = await supabase.rpc('send_challenge_reminders');
    if (error) {
      console.error('Erreur lors de l\'envoi des rappels:', error);
      return;
    }
    console.log('Rappels envoyés avec succès');
  } catch (error) {
    console.error('Erreur générale lors de l\'envoi des rappels:', error);
  }
});

// Démarrage des jobs cron
const startCronJobs = () => {
  generateWeeklyChallenges.start();
  processChallengeResults.start();
  sendChallengeReminders.start();
  console.log('Jobs cron démarrés avec succès');
};

// Arrêt des jobs cron
const stopCronJobs = () => {
  generateWeeklyChallenges.stop();
  processChallengeResults.stop();
  sendChallengeReminders.stop();
  console.log('Jobs cron arrêtés avec succès');
};

// Export des fonctions de gestion des jobs
cronJobs = {
  start: startCronJobs,
  stop: stopCronJobs
};

// Validation des challenges
const validateChallenge = async (userId, challengeData) => {
  try {
    // Vérification du thème
    const { data: theme, error: themeError } = await supabase
      .from('challenge_themes')
      .select('id')
      .eq('id', challengeData.theme_id)
      .eq('is_active', true)
      .single();

    if (themeError) {
      console.error('Erreur lors de la vérification du thème:', themeError);
      throw themeError;
    }
    if (!theme) {
      throw new Error('Thème invalide ou inactif');
    }

    // Vérification de l'abonnement Gold
    const { data: subscription, error: subscriptionError } = await supabase
      .from('subscriptions')
      .select('type')
      .eq('user_id', userId)
      .eq('is_active', true)
      .single();

    if (subscriptionError) {
      console.error('Erreur lors de la vérification de l\'abonnement:', subscriptionError);
      throw subscriptionError;
    }
    if (!subscription || subscription.type !== BADGES.GOLD) {
      throw new Error('Seuls les abonnés Gold peuvent créer des challenges');
    }

    return true;
  } catch (error) {
    console.error('Erreur lors de la validation du challenge:', error);
    throw error;
  }
};

// Envoi de notifications
const sendNotification = async (userId, type, title, message, data) => {
  try {
    const notificationData = {
      user_id: userId,
      type,
      title,
      message,
      data: JSON.stringify(data),
      created_at: new Date(),
      updated_at: new Date()
    };

    const { error } = await supabase
      .from('notifications')
      .insert(notificationData);

    if (error) {
      console.error('Erreur lors de l\'envoi de la notification:', error);
      throw error;
    }

    return true;
  } catch (error) {
    console.error('Erreur générale lors de l\'envoi de la notification:', error);
    throw error;
  }
};

// Calcul des récompenses des challenges
const calculateChallengeRewards = (rank) => {
  switch (rank) {
    case 1: return CHALLENGE_REWARDS.FIRST_PLACE; // 🥇 1er place
    case 2: return CHALLENGE_REWARDS.SECOND_PLACE; // 🥈 2e place
    case 3: return CHALLENGE_REWARDS.THIRD_PLACE; // 🥉 3e place
    default: return 0;
  }
};

// Calcul des récompenses pour les participants (> 100 likes)
const calculateParticipantReward = () => CHALLENGE_REWARDS.PARTICIPANT;

// Get active challenges
const getActiveChallenges = async () => {
  try {
    const { data: challenges, error } = await supabase
      .from('challenges')
      .select('*')
      .eq('status', 'active')
      .order('start_date', { ascending: true });

    if (error) throw error;
    return challenges || [];
  } catch (error) {
    throw error;
  }
};

// Création d'un challenge (proposé par un utilisateur)
const createChallenge = async (userId, challengeData) => {
  try {
    // Validation du challenge
    await validateChallenge(userId, challengeData);

    // Création du challenge
    const { data, error } = await supabase
      .from('challenges')
      .insert({
        ...challengeData,
        created_by: userId,
        status: CHALLENGE_STATUSES.PENDING,
        type: CHALLENGE_TYPES.USER_SUBMITTED,
        created_at: new Date(),
        updated_at: new Date(),
      })
      .select()
      .single();

    if (error) {
      console.error('Erreur lors de la création du challenge:', error);
      throw error;
    }

    // Envoi de la notification à l'admin
    const adminUserId = process.env.ADMIN_USER_ID || 'admin_user_id';
    await sendNotification(
      adminUserId,
      NOTIFICATION_TYPES.CHALLENGE_SUBMITTED,
      'Nouveau Challenge Soumis',
      `Nouveau challenge soumis par ${userId}`,
      { challenge_id: data.id }
    );

    return data;
  } catch (error) {
    console.error('Erreur générale lors de la création du challenge:', error);
    throw error;
  }
};

// Approve challenge (admin only)
const approveChallenge = async (challengeId) => {
  try {
    const { error } = await supabase
      .from('challenges')
      .update({
        status: 'active',
        approved: true,
        updated_at: new Date(),
      })
      .eq('id', challengeId)
      .eq('status', 'pending');

    if (error) throw error;

    // Send notification to creator
    const { data: challenge } = await supabase
      .from('challenges')
      .select('created_by')
      .eq('id', challengeId)
      .single();

    await sendNotification(
      challenge.created_by,
      'challenge_approved',
      'Challenge Approved',
      'Your challenge has been approved and is now active!',
      { challenge_id: challengeId }
    );

    return { success: true, message: 'Challenge approved successfully' };
  } catch (error) {
    throw error;
  }
};

// Reject challenge (admin only)
const rejectChallenge = async (challengeId, reason) => {
  try {
    const { error } = await supabase
      .from('challenges')
      .update({
        status: 'cancelled',
        approved: false,
        updated_at: new Date(),
      })
      .eq('id', challengeId)
      .eq('status', 'pending');

    if (error) throw error;

    // Send notification to creator
    const { data: challenge } = await supabase
      .from('challenges')
      .select('created_by')
      .eq('id', challengeId)
      .single();

    await sendNotification(
      challenge.created_by,
      'challenge_rejected',
      'Challenge Rejected',
      `Your challenge has been rejected: ${reason}`,
      { challenge_id: challengeId, reason }
    );

    return { success: true, message: 'Challenge rejected successfully' };
  } catch (error) {
    throw error;
  }
};

// Participate in challenge
const participateInChallenge = async (userId, challengeId, memeId) => {
  try {
    // Check if challenge exists and is active
    const { data: challenge, error: challengeError } = await supabase
      .from('challenges')
      .select('*')
      .eq('id', challengeId)
      .eq('status', 'active')
      .single();

    if (challengeError) throw challengeError;
    if (!challenge) throw new Error('Challenge not found or not active');

    // Check if user has already participated
    const { data: existingParticipation, error: existingError } = await supabase
      .from('challenge_participations')
      .select('id')
      .eq('challenge_id', challengeId)
      .eq('user_id', userId)
      .single();

    if (existingError && existingError.code !== 'PGRST116') {
      throw existingError;
    }

    if (existingParticipation) {
      throw new Error('Already participated in this challenge');
    }

    // Create participation
    const { error: insertError } = await supabase
      .from('challenge_participations')
      .insert({
        challenge_id: challengeId,
        meme_id: memeId,
        user_id: userId,
        submission_date: new Date(),
      });

    if (participationError) throw participationError;

    return { success: true, message: 'Successfully participated in challenge' };
  } catch (error) {
    throw error;
  }
};

// Get challenge results
const getChallengeResults = async (challengeId) => {
  try {
    // Get challenge details
    const { data: challenge, error: challengeError } = await supabase
      .from('challenges')
      .select('*')
      .eq('id', challengeId)
      .single();

    if (challengeError) throw challengeError;
    if (!challenge) throw new Error('Challenge not found');

    // Get participations with rankings
    const { data: participations, error: participationsError } = await supabase
      .from('meme_challenge_participations')
      .select('*, users:users!user_id(*)')
      .eq('challenge_id', challengeId)
      .order('submission_date', { ascending: false });

    if (participationsError) throw participationsError;

    // Calculate rankings
    const rankings = await supabase
      .rpc('calculate_challenge_rankings', { challenge_id: challengeId });

    // Add rankings to participations
    const rankedParticipations = participations.map(participation => {
      const rank = rankings.find(r => r.meme_id === participation.meme_id);
      return {
        ...participation,
        rank: rank?.rank || 0,
        total_likes: rank?.total_likes || 0,
        reward: calculateChallengeRewards(rank?.rank || 0)
      };
    });

    return {
      challenge,
      participations: rankedParticipations,
      total_participants: rankedParticipations.length
    };
  } catch (error) {
    throw error;
  }
};

// Report challenge participation
const reportChallengeParticipation = async (userId, participationId, reason) => {
  try {
    // Check if participation exists
    const { data: participation, error: participationError } = await supabase
      .from('meme_challenge_participations')
      .select('*')
      .eq('id', participationId)
      .single();

    if (participationError) throw participationError;
    if (!participation) throw new Error('Participation not found');

    // Create report
    const { error: reportError } = await supabase
      .from('challenge_reports')
      .insert({
        challenge_id: participation.challenge_id,
        reported_by: userId,
        reason,
        created_at: new Date(),
      });

    if (reportError) throw reportError;

    return { success: true, message: 'Challenge participation reported successfully' };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  getActiveChallenges,
  createChallenge,
  participateInChallenge,
  getChallengeResults,
  reportChallengeParticipation,
};
