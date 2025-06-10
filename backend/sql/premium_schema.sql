-- Add new enums
CREATE TYPE upload_pack_type AS ENUM ('daily', 'weekly', 'monthly');
CREATE TYPE payment_provider AS ENUM ('stripe', 'cinetpay', 'orange_money', 'mtn', 'moov', 'wave');

-- Add new tables
CREATE TABLE upload_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    extra_uploads INTEGER NOT NULL,
    price_lolcoins INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE meme_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    meme_id UUID REFERENCES memes(id) ON DELETE CASCADE,
    price_lolcoins INTEGER NOT NULL,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id, meme_id)
);

CREATE TABLE lolcoin_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    amount_lolcoins INTEGER NOT NULL,
    price_fcfa INTEGER NOT NULL,
    price_eur INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add new columns to existing tables
ALTER TABLE memes ADD COLUMN is_premium BOOLEAN DEFAULT false;
ALTER TABLE memes ADD COLUMN price_lolcoins INTEGER;

-- Add indexes
CREATE INDEX idx_meme_purchases_user_id ON meme_purchases(user_id);
CREATE INDEX idx_meme_purchases_meme_id ON meme_purchases(meme_id);
CREATE INDEX idx_upload_packs_title ON upload_packs(title);
CREATE INDEX idx_lolcoin_packs_name ON lolcoin_packs(name);

-- Add triggers for timestamps
CREATE TRIGGER update_upload_packs_updated_at
    BEFORE UPDATE ON upload_packs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lolcoin_packs_updated_at
    BEFORE UPDATE ON lolcoin_packs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default data
INSERT INTO upload_packs (title, extra_uploads, price_lolcoins, description)
VALUES
    ('Daily Boost', 10, 100, '10 extra uploads for today'),
    ('Weekly Boost', 50, 500, '50 extra uploads for this week'),
    ('Monthly Boost', 200, 2000, '200 extra uploads for this month');

INSERT INTO lolcoin_packs (name, amount_lolcoins, price_fcfa, price_eur, is_active)
VALUES
    ('Starter Pack', 500, 1000, 2, true),
    ('Bronze Pack', 1000, 2000, 3.5, true),
    ('Silver Pack', 2500, 5000, 8, true),
    ('Gold Pack', 5000, 10000, 14, true),
    ('Creator Pack', 10000, 16000, 25, true);

-- Add constraints
ALTER TABLE memes 
ADD CONSTRAINT check_premium_price 
CHECK ((is_premium = false AND price_lolcoins IS NULL) OR (is_premium = true AND price_lolcoins IS NOT NULL));

-- Add functions for business logic
CREATE OR REPLACE FUNCTION check_lolcoins_sufficient(
    user_id UUID,
    amount INTEGER,
    use_purchased BOOLEAN
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM users 
        WHERE id = user_id 
        AND (
            (use_purchased = true AND lolcoins_purchased >= amount) 
            OR (use_purchased = false AND lolcoins_earned >= amount)
        )
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deduct_lolcoins(
    user_id UUID,
    amount INTEGER,
    use_purchased BOOLEAN
) RETURNS INTEGER AS $$
BEGIN
    IF use_purchased THEN
        UPDATE users 
        SET lolcoins_purchased = lolcoins_purchased - amount,
            updated_at = now()
        WHERE id = user_id;
        RETURN 1;
    ELSE
        UPDATE users 
        SET lolcoins_earned = lolcoins_earned - amount,
            updated_at = now()
        WHERE id = user_id;
        RETURN 2;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add triggers for meme purchases
CREATE OR REPLACE FUNCTION update_meme_purchase()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if user has enough LOLCoins
    IF NOT check_lolcoins_sufficient(NEW.user_id, NEW.price_lolcoins, false) THEN
        RAISE EXCEPTION 'Insufficient LOLCoins for purchase';
    END IF;

    -- Deduct LOLCoins
    PERFORM deduct_lolcoins(NEW.user_id, NEW.price_lolcoins, false);

    -- Create transaction record
    INSERT INTO lolcoin_transactions (user_id, type, amount, description)
    VALUES (NEW.user_id, 'used', NEW.price_lolcoins, 'Purchased premium meme');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_meme_purchase_trigger
    BEFORE INSERT ON meme_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_meme_purchase();

-- Add triggers for upload packs
CREATE OR REPLACE FUNCTION update_upload_pack_purchase()
RETURNS TRIGGER AS $$
DECLARE
    pack upload_packs;
BEGIN
    -- Get pack details
    SELECT * INTO pack FROM upload_packs WHERE id = NEW.upload_pack_id;
    
    -- Check if user has enough LOLCoins
    IF NOT check_lolcoins_sufficient(NEW.user_id, pack.price_lolcoins, true) THEN
        RAISE EXCEPTION 'Insufficient purchased LOLCoins for upload pack';
    END IF;

    -- Deduct LOLCoins
    PERFORM deduct_lolcoins(NEW.user_id, pack.price_lolcoins, true);

    -- Create transaction record
    INSERT INTO lolcoin_transactions (user_id, type, amount, description)
    VALUES (NEW.user_id, 'used', pack.price_lolcoins, 'Purchased upload pack');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_upload_pack_purchase_trigger
    BEFORE INSERT ON upload_pack_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_upload_pack_purchase();
