const { Pool } = require('pg');
const crypto = require('crypto');
const AWS = require('aws-sdk');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Configure AWS S3
AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: 'eu-central-1',
});

const s3 = new AWS.S3();

class MemeSyncService {
  constructor(userId, deviceId) {
    this.userId = userId;
    this.deviceId = deviceId;
    this.bucketName = 'lolzone-memes';
  }

  async getPreferences() {
    try {
      const result = await pool.query(
        'SELECT * FROM user_preferences WHERE user_id = $1 AND device_id = $2 ORDER BY updated_at DESC LIMIT 1',
        [this.userId, this.deviceId]
      );

      if (result.rows.length === 0) {
        return {
          theme: 'light',
          fontSize: 16,
          fontColor: '#000000',
          autoSave: true,
          autoSync: true,
          lastSync: null
        };
      }

      return JSON.parse(result.rows[0].preferences);
    } catch (error) {
      console.error('Error fetching preferences:', error);
      throw error;
    }
  }

  async savePreferences(preferences) {
    try {
      await pool.query(
        'INSERT INTO user_preferences (user_id, device_id, preferences) VALUES ($1, $2, $3)',
        [this.userId, this.deviceId, JSON.stringify(preferences)]
      );
    } catch (error) {
      console.error('Error saving preferences:', error);
      throw error;
    }
  }

  async handleSyncConflict(memeId, localMeme, cloudMeme) {
    try {
      // Check if there's already a conflict for this meme
      const conflictResult = await pool.query(
        'SELECT * FROM meme_sync_conflicts WHERE meme_id = $1 AND resolved_at IS NULL',
        [memeId]
      );

      if (conflictResult.rows.length > 0) {
        // Update existing conflict
        await pool.query(
          'UPDATE meme_sync_conflicts SET local_version = $1, cloud_version = $2 WHERE id = $3',
          [JSON.stringify(localMeme), JSON.stringify(cloudMeme), conflictResult.rows[0].id]
        );
        return;
      }

      // Create new conflict
      await pool.query(
        'INSERT INTO meme_sync_conflicts (meme_id, user_id, device_id, conflict_type, local_version, cloud_version) ' +
        'VALUES ($1, $2, $3, $4, $5, $6)',
        [
          memeId,
          this.userId,
          this.deviceId,
          'content',
          JSON.stringify(localMeme),
          JSON.stringify(cloudMeme)
        ]
      );

      // Log the conflict
      console.log(`Conflict detected for meme ${memeId}:`, {
        local: localMeme,
        cloud: cloudMeme
      });
    } catch (error) {
      console.error('Error handling sync conflict:', error);
      throw error;
    }
  }

  async resolveConflict(conflictId, resolutionType) {
    try {
      await pool.query(
        'UPDATE meme_sync_conflicts SET resolved_at = NOW(), resolution_type = $1 WHERE id = $2',
        [resolutionType, conflictId]
      );
    } catch (error) {
      console.error('Error resolving conflict:', error);
      throw error;
    }
  }

  async getUnresolvedConflicts() {
    try {
      const result = await pool.query(
        'SELECT * FROM meme_sync_conflicts WHERE resolved_at IS NULL ORDER BY created_at DESC'
      );
      return result.rows;
    } catch (error) {
      console.error('Error fetching unresolved conflicts:', error);
      throw error;
    }
  }

  async logMemeVersion(memeId, version) {
    try {
      await pool.query(
        'INSERT INTO meme_version_history (meme_id, user_id, device_id, version) VALUES ($1, $2, $3, $4)',
        [memeId, this.userId, this.deviceId, JSON.stringify(version)]
      );
    } catch (error) {
      console.error('Error logging meme version:', error);
      throw error;
    }
  }

  async getMemeHistory(memeId) {
    try {
      const result = await pool.query(
        'SELECT * FROM meme_version_history WHERE meme_id = $1 ORDER BY created_at DESC',
        [memeId]
      );
      return result.rows;
    } catch (error) {
      console.error('Error fetching meme history:', error);
      throw error;
    }
  }

  async syncMemeToCloud(memeData) {
    try {
      // Get existing meme if it exists
      const existingMemeResult = await pool.query(
        'SELECT * FROM user_memes WHERE id = $1 AND user_id = $2',
        [memeData.id, this.userId]
      );

      let existingMeme = null;
      if (existingMemeResult.rows.length > 0) {
        existingMeme = existingMemeResult.rows[0];
      }

      // Generate unique ID if new meme
      const memeId = memeData.id || crypto.randomUUID();
      
      // Upload image to S3 if it's a local file
      let imageUrl = memeData.imageUrl;
      if (!imageUrl.startsWith('http')) {
        const fileKey = `user_${this.userId}/memes/${memeId}/image.png`;
        const fileBuffer = await this.readFile(imageUrl);
        
        await s3.upload({
          Bucket: this.bucketName,
          Key: fileKey,
          Body: fileBuffer,
          ContentType: 'image/png',
          ACL: 'private',
        }).promise();
        
        imageUrl = `https://${this.bucketName}.s3.amazonaws.com/${fileKey}`;
      }

      // Handle conflict if meme exists and content is different
      if (existingMeme && existingMeme.image_url !== imageUrl) {
        await this.handleSyncConflict(memeId, memeData, existingMeme);
      }

      // Save meme metadata to database
      const result = await pool.query(
        existingMeme ? 
          'UPDATE user_memes SET image_url = $3, texts = $4, description = $5, hashtags = $6, updated_at = NOW() WHERE id = $1 AND user_id = $2 RETURNING *' :
          'INSERT INTO user_memes (id, user_id, image_url, texts, description, hashtags, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW()) RETURNING *',
        [
          memeId,
          this.userId,
          imageUrl,
          JSON.stringify(memeData.texts),
          memeData.description,
          JSON.stringify(memeData.hashtags),
        ]
      );

      // Log the version
      await this.logMemeVersion(memeId, memeData);

      return result.rows[0];
    } catch (error) {
      console.error('Error syncing meme to cloud:', error);
      throw error;
    }
  }

  async getSyncedMemes() {
    try {
      const result = await pool.query(
        'SELECT * FROM user_memes WHERE user_id = $1 ORDER BY updated_at DESC',
        [this.userId]
      );
      return result.rows;
    } catch (error) {
      console.error('Error fetching synced memes:', error);
      throw error;
    }
  }

  async syncMemeToDevice(memeId) {
    try {
      const result = await pool.query(
        'SELECT * FROM user_memes WHERE id = $1 AND user_id = $2',
        [memeId, this.userId]
      );

      if (result.rows.length === 0) {
        throw new Error('Meme not found');
      }

      const meme = result.rows[0];
      return {
        id: meme.id,
        imageUrl: meme.image_url,
        texts: JSON.parse(meme.texts),
        description: meme.description,
        hashtags: JSON.parse(meme.hashtags),
        createdAt: meme.created_at,
        updatedAt: meme.updated_at,
      };
    } catch (error) {
      console.error('Error syncing meme to device:', error);
      throw error;
    }
  }

  async deleteSyncedMeme(memeId) {
    try {
      // Delete from database
      await pool.query(
        'DELETE FROM user_memes WHERE id = $1 AND user_id = $2',
        [memeId, this.userId]
      );

      // Delete image from S3 if it exists
      const params = {
        Bucket: this.bucketName,
        Key: `user_${this.userId}/memes/${memeId}/image.png`,
      };

      try {
        await s3.deleteObject(params).promise();
      } catch (error) {
        // If file doesn't exist, just continue
        if (error.code !== 'NoSuchKey') {
          throw error;
        }
      }
    } catch (error) {
      console.error('Error deleting synced meme:', error);
      throw error;
    }
  }

  async readFile(filePath) {
    return new Promise((resolve, reject) => {
      const fs = require('fs');
      fs.readFile(filePath, (err, data) => {
        if (err) reject(err);
        resolve(data);
      });
    });
  }
}

module.exports = MemeSyncService;
