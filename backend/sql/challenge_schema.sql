-- Add new enums
CREATE TYPE challenge_status AS ENUM ('pending', 'active', 'completed', 'cancelled');
CREATE TYPE challenge_type AS ENUM ('automatic', 'user_submitted');

-- Create challenges table
CREATE TABLE challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    theme TEXT NOT NULL,
    created_by UUID REFERENCES users(id) ON DELETE CASCADE,
    approved BOOLEAN DEFAULT FALSE,
    status challenge_status DEFAULT 'pending',
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    reward_lolcoins INTEGER DEFAULT 500,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create meme challenge participations table
CREATE TABLE meme_challenge_participations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    meme_id UUID REFERENCES memes(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    score INTEGER DEFAULT 0,
    submission_date TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(challenge_id, user_id)
);

-- Create challenge themes table
CREATE TABLE challenge_themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create challenge reports table
CREATE TABLE challenge_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID REFERENCES challenges(id) ON DELETE CASCADE,
    reported_by UUID REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_challenges_status ON challenges(status);
CREATE INDEX idx_challenges_start_date ON challenges(start_date);
CREATE INDEX idx_challenges_end_date ON challenges(end_date);
CREATE INDEX idx_meme_participations_challenge_id ON meme_challenge_participations(challenge_id);
CREATE INDEX idx_meme_participations_user_id ON meme_challenge_participations(user_id);
CREATE INDEX idx_challenge_reports_challenge_id ON challenge_reports(challenge_id);
CREATE INDEX idx_challenge_reports_reported_by ON challenge_reports(reported_by);

-- Add triggers for timestamps
CREATE TRIGGER update_challenges_updated_at
    BEFORE UPDATE ON challenges
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meme_participations_updated_at
    BEFORE UPDATE ON meme_challenge_participations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_challenge_reports_updated_at
    BEFORE UPDATE ON challenge_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add default themes
INSERT INTO challenge_themes (name, description, category) VALUES
    ('Teacher Meme', 'Memes related to education and teachers', 'Education'),
    ('Transportation Meme', 'Memes about transportation and vehicles', 'Transport'),
    ('Workplace Meme', 'Memes about office life and jobs', 'Work'),
    ('Relationship Meme', 'Memes about relationships and love', 'Relationship'),
    ('School Life Meme', 'Memes about school and student life', 'Education'),
    ('Food Meme', 'Memes about food and cooking', 'Food'),
    ('Pet Meme', 'Memes about pets and animals', 'Animals');

-- Add functions for challenge management
CREATE OR REPLACE FUNCTION update_challenge_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'active' AND (NEW.start_date IS NULL OR NEW.end_date IS NULL) THEN
        RAISE EXCEPTION 'Start and end dates are required for active challenges';
    END IF;

    IF NEW.status = 'active' AND NEW.start_date > NEW.end_date THEN
        RAISE EXCEPTION 'End date must be after start date';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_challenge_status_trigger
    BEFORE UPDATE ON challenges
    FOR EACH ROW
    EXECUTE FUNCTION update_challenge_status();

-- Add function to calculate challenge rankings
CREATE OR REPLACE FUNCTION calculate_challenge_rankings(challenge_id UUID)
RETURNS TABLE(
    user_id UUID,
    meme_id UUID,
    total_likes INTEGER,
    rank INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.user_id,
        p.meme_id,
        COALESCE(SUM(l.count), 0) as total_likes,
        RANK() OVER (ORDER BY COALESCE(SUM(l.count), 0) DESC) as rank
    FROM meme_challenge_participations p
    LEFT JOIN likes l ON p.meme_id = l.meme_id
    WHERE p.challenge_id = challenge_id
    GROUP BY p.user_id, p.meme_id;
END;
$$ LANGUAGE plpgsql;
