const { supabase } = require('../config/supabase');
const { validateFile } = require('./utils/fileValidator');
const { checkUserBalance } = require('./premiumService');

// Image categories and types
const IMAGE_CATEGORIES = [
  'animals', 'school', 'sports', 'food', 'travel',
  'funny', 'dark', 'wholesome', 'other'
];

// Price tiers for premium images
const IMAGE_PRICE_TIERS = {
  common: { id: 1, price: 10 },
  uncommon: { id: 2, price: 25 },
  rare: { id: 3, price: 50 },
  epic: { id: 4, price: 100 }
};

// Validate image upload
const validateImageUpload = (file) => {
  if (!file) throw new Error('No file provided');
  if (!['image/jpeg', 'image/png', 'video/mp4'].includes(file.mimetype)) {
    throw new Error('Invalid file type. Only JPG, PNG and MP4 are allowed');
  }
  if (file.size > 5 * 1024 * 1024) {
    throw new Error('File size exceeds 5MB limit');
  }
  return true;
};

// Upload user image
const uploadUserImage = async (userId, file, data = {}) => {
  try {
    validateImageUpload(file);
    
    // Generate unique filename
    const filename = `user_images/${userId}-${Date.now()}-${file.originalname}`;
    
    // Upload to storage
    const { error: uploadError } = await supabase.storage
      .from('images')
      .upload(filename, file.buffer, {
        cacheControl: '3600',
        upsert: false
      });

    if (uploadError) throw uploadError;

    // Get public URL
    const { data: { publicUrl } } = await supabase.storage
      .from('images')
      .getPublicUrl(filename);

    // Create image record
    const { error: dbError } = await supabase
      .from('images')
      .insert({
        url: publicUrl,
        title: data.title || file.originalname,
        description: data.description,
        category: data.category || 'other',
        type: 'free',
        created_by: userId
      });

    if (dbError) throw dbError;

    return {
      success: true,
      url: publicUrl,
      filename
    };
  } catch (error) {
    throw error;
  }
};

// Get gallery images
const getGalleryImages = async (category = null, type = null, limit = 20) => {
  try {
    const query = supabase
      .from('images')
      .select('*')
      .eq('approved', true)
      .eq('nsfw', false);

    if (category) {
      query.eq('category', category);
    }

    if (type) {
      query.eq('type', type);
    }

    const { data, error } = await query.limit(limit);

    if (error) throw error;
    return data;
  } catch (error) {
    throw error;
  }
};

// Purchase premium image
const purchasePremiumImage = async (userId, imageId) => {
  try {
    // Check if image exists and is premium
    const { data: image, error: fetchError } = await supabase
      .from('images')
      .select('*')
      .eq('id', imageId)
      .eq('type', 'premium')
      .single();

    if (fetchError) throw fetchError;
    if (!image) throw new Error('Image not found');

    // Check user balance
    const hasSufficientBalance = await checkUserBalance(userId, image.price_lolcoins);
    if (!hasSufficientBalance) {
      throw new Error('Insufficient LOLCoins balance');
    }

    // Deduct LOLCoins
    const { error: deductError } = await supabase
      .from('user_lolcoins')
      .update({ balance: supabase.raw('balance - ?::integer', [image.price_lolcoins]) })
      .eq('user_id', userId);

    if (deductError) throw deductError;

    // Add to user's purchased images
    const { error: purchaseError } = await supabase
      .from('user_purchased_images')
      .insert({
        user_id: userId,
        image_id: imageId,
        purchased_at: new Date()
      });

    if (purchaseError) throw purchaseError;

    return {
      success: true,
      image,
      deducted_lolcoins: image.price_lolcoins
    };
  } catch (error) {
    throw error;
  }
};

// Create meme with text
const createMeme = async (userId, data) => {
  try {
    // Validate meme data
    if (!data.description || data.description.length > 500) {
      throw new Error('Invalid meme description');
    }

    // Create meme record
    const { data: meme, error: memeError } = await supabase
      .from('memes')
      .insert({
        description: data.description,
        hashtags: data.hashtags || [],
        user_id: userId,
        created_at: new Date()
      })
      .select()
      .single();

    if (memeError) throw memeError;

    // Add images to meme
    const imagePromises = data.images.map(async (imageId) => {
      const { error: error } = await supabase
        .from('meme_images')
        .insert({
          meme_id: meme.id,
          image_id: imageId
        });

      if (error) throw error;
    });

    await Promise.all(imagePromises);

    // Add text overlays
    if (data.texts && data.texts.length > 0) {
      const textPromises = data.texts.map(async (text) => {
        const { error: error } = await supabase
          .from('meme_texts')
          .insert({
            meme_id: meme.id,
            text: text.text,
            position: text.position,
            font_family: text.font,
            color: text.color,
            size: text.size
          });

        if (error) throw error;
      });

      await Promise.all(textPromises);
    }

    return {
      success: true,
      meme
    };
  } catch (error) {
    throw error;
  }
};

// Admin functions
const importImages = async (userId, files, metadata) => {
  try {
    if (!files || files.length === 0) {
      throw new Error('No files provided');
    }

    const results = [];
    for (const file of files) {
      validateImageUpload(file);
      
      // Generate unique filename
      const filename = `admin_import/${userId}-${Date.now()}-${file.originalname}`;
      
      // Upload to storage
      const { error: uploadError } = await supabase.storage
        .from('images')
        .upload(filename, file.buffer, {
          cacheControl: '3600',
          upsert: false
        });

      if (uploadError) throw uploadError;

      // Get public URL
      const { data: { publicUrl } } = await supabase.storage
        .from('images')
        .getPublicUrl(filename);

      // Create image record
      const { error: dbError } = await supabase
        .from('images')
        .insert({
          url: publicUrl,
          title: metadata.title || file.originalname,
          description: metadata.description,
          category: metadata.category || 'other',
          type: metadata.type || 'free',
          price_lolcoins: metadata.price_lolcoins || 0,
          created_by: userId,
          approved: metadata.approved || false
        });

      if (dbError) throw dbError;

      results.push({
        success: true,
        url: publicUrl,
        filename
      });
    }

    return results;
  } catch (error) {
    throw error;
  }
};

// Update image status
const updateImageStatus = async (userId, imageId, status) => {
  try {
    // Verify admin role
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('role')
      .eq('id', userId)
      .single();

    if (userError) throw userError;
    if (user.role !== 'admin') {
      throw new Error('Unauthorized: Admin access required');
    }

    // Update image status
    const { error: updateError } = await supabase
      .from('images')
      .update({
        approved: status.approved,
        nsfw: status.nsfw,
        updated_at: new Date()
      })
      .eq('id', imageId);

    if (updateError) throw updateError;

    return { success: true };
  } catch (error) {
    throw error;
  }
};

module.exports = {
  uploadUserImage,
  getGalleryImages,
  purchasePremiumImage,
  createMeme,
  importImages,
  updateImageStatus,
  IMAGE_CATEGORIES,
  IMAGE_PRICE_TIERS
};
