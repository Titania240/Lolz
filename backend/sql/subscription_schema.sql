-- Add subscription type enum
CREATE TYPE subscription_type AS ENUM ('bronze', 'silver', 'gold');

-- Add subscription table
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type subscription_type NOT NULL,
    price_fcfa INTEGER NOT NULL,
    price_eur INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
    end_date TIMESTAMP WITH TIME ZONE,
    payment_method TEXT,
    transaction_reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add indexes
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_type ON subscriptions(type);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date);

-- Add triggers for timestamps
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add function to update user badge on subscription change
CREATE OR REPLACE FUNCTION update_user_badge()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user's badge
    UPDATE users 
    SET badge = NEW.type,
        updated_at = now()
    WHERE id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to update badge on subscription change
CREATE TRIGGER update_user_badge_trigger
    AFTER INSERT OR UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_badge();

-- Add function to handle subscription expiration
CREATE OR REPLACE FUNCTION handle_subscription_expiration()
RETURNS TRIGGER AS $$
BEGIN
    -- If subscription is ending
    IF NEW.end_date IS NOT NULL AND NEW.end_date <= now() THEN
        -- Deactivate subscription
        NEW.is_active = false;
        
        -- Update user's badge to 'none'
        UPDATE users 
        SET badge = 'none',
            updated_at = now()
        WHERE id = NEW.user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to handle expiration
CREATE TRIGGER handle_subscription_expiration_trigger
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION handle_subscription_expiration();
