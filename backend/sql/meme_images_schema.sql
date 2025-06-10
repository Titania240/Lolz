-- Create enum for image types
CREATE TYPE image_type AS ENUM ('free', 'premium');

-- Create enum for image categories
CREATE TYPE image_category AS ENUM (
    'animals',
    'school',
    'sports',
    'food',
    'travel',
    'funny',
    'dark',
    'wholesome',
    'other'
);

-- Create images table
CREATE TABLE images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    category image_category NOT NULL,
    type image_type NOT NULL,
    price_lolcoins INTEGER DEFAULT 0,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    approved BOOLEAN DEFAULT FALSE,
    nsfw BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(url)
);

-- Create image prices table
CREATE TABLE image_prices (
    price_tier INTEGER PRIMARY KEY,
    description TEXT NOT NULL,
    price_lolcoins INTEGER NOT NULL
);

-- Insert default price tiers
INSERT INTO image_prices (price_tier, description, price_lolcoins) VALUES
    (1, 'Common', 10),
    (2, 'Uncommon', 25),
    (3, 'Rare', 50),
    (4, 'Epic', 100);

-- Create meme_texts table
CREATE TABLE meme_texts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meme_id UUID REFERENCES memes(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    position TEXT CHECK (position IN ('top', 'bottom')),
    font_family TEXT,
    color TEXT,
    size INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create meme_images table (many-to-many relationship)
CREATE TABLE meme_images (
    meme_id UUID REFERENCES memes(id) ON DELETE CASCADE,
    image_id UUID REFERENCES images(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    PRIMARY KEY (meme_id, image_id)
);

-- Create audit table for image actions
CREATE TABLE image_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    image_id UUID REFERENCES images(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create triggers for timestamps
CREATE OR REPLACE FUNCTION update_images_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_images_updated_at
    BEFORE UPDATE ON images
    FOR EACH ROW
    EXECUTE FUNCTION update_images_updated_at();

-- Create trigger for automatic audit logging
CREATE OR REPLACE FUNCTION log_image_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO image_audit (image_id, user_id, action, description)
    VALUES (
        NEW.id,
        NEW.created_by,
        CASE
            WHEN TG_OP = 'INSERT' THEN 'CREATE'
            WHEN TG_OP = 'UPDATE' THEN 'UPDATE'
            ELSE 'DELETE'
        END,
        CASE
            WHEN TG_OP = 'UPDATE' THEN 'Image updated'
            WHEN TG_OP = 'DELETE' THEN 'Image deleted'
            ELSE 'Image created'
        END
    );
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER log_image_action
    AFTER INSERT OR UPDATE OR DELETE ON images
    FOR EACH ROW
    EXECUTE FUNCTION log_image_action();

-- Create index for faster searches
CREATE INDEX idx_images_category ON images(category);
CREATE INDEX idx_images_type ON images(type);
CREATE INDEX idx_images_approved ON images(approved);
CREATE INDEX idx_images_nsfw ON images(nsfw);
CREATE INDEX idx_meme_images_meme ON meme_images(meme_id);
CREATE INDEX idx_meme_images_image ON meme_images(image_id);
