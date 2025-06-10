-- Table pour stocker les conflits de synchronisation
CREATE TABLE IF NOT EXISTS meme_sync_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meme_id UUID NOT NULL,
    user_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    conflict_type VARCHAR(50) NOT NULL,
    local_version JSONB,
    cloud_version JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_type VARCHAR(50),
    FOREIGN KEY (meme_id) REFERENCES user_memes(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Table pour stocker les préférences utilisateur
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    preferences JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Trigger pour mettre à jour le timestamp des préférences
CREATE OR REPLACE FUNCTION update_preferences_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_preferences_timestamp
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_preferences_timestamp();

-- Table pour stocker l'historique des modifications
CREATE TABLE IF NOT EXISTS meme_version_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meme_id UUID NOT NULL,
    user_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    version JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meme_id) REFERENCES user_memes(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Index pour optimiser les requêtes de conflits
CREATE INDEX IF NOT EXISTS idx_meme_sync_conflicts_meme_id ON meme_sync_conflicts(meme_id);
CREATE INDEX IF NOT EXISTS idx_meme_sync_conflicts_user_id ON meme_sync_conflicts(user_id);
CREATE INDEX IF NOT EXISTS idx_meme_sync_conflicts_device_id ON meme_sync_conflicts(device_id);

-- Index pour optimiser les requêtes de préférences
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_device_id ON user_preferences(device_id);

-- Index pour optimiser l'historique des versions
CREATE INDEX IF NOT EXISTS idx_meme_version_history_meme_id ON meme_version_history(meme_id);
CREATE INDEX IF NOT EXISTS idx_meme_version_history_user_id ON meme_version_history(user_id);
CREATE INDEX IF NOT EXISTS idx_meme_version_history_device_id ON meme_version_history(device_id);
CREATE INDEX IF NOT EXISTS idx_meme_version_history_created_at ON meme_version_history(created_at);
