-- Add notification types
CREATE TYPE notification_type AS ENUM ('challenge_won', 'challenge_reminder', 'challenge_started', 'challenge_ended');

-- Add notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Add challenge generation table
CREATE TABLE automatic_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_id UUID REFERENCES challenge_themes(id) ON DELETE CASCADE,
    challenge_id UUID REFERENCES challenges(id) ON DELETE SET NULL,
    week_number INTEGER NOT NULL,
    year INTEGER NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(week_number, year)
);

-- Add indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_automatic_challenges_week_year ON automatic_challenges(week_number, year);

-- Add triggers for timestamps
CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_automatic_challenges_updated_at
    BEFORE UPDATE ON automatic_challenges
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add function to generate weekly challenges
CREATE OR REPLACE FUNCTION generate_weekly_challenges()
RETURNS void AS $$
DECLARE
    current_week INTEGER;
    current_year INTEGER;
    theme challenge_themes%ROWTYPE;
BEGIN
    -- Get current week and year
    SELECT EXTRACT(WEEK FROM now())::INTEGER INTO current_week;
    SELECT EXTRACT(YEAR FROM now())::INTEGER INTO current_year;

    -- Check if challenge already exists for this week
    IF NOT EXISTS (
        SELECT 1 
        FROM automatic_challenges 
        WHERE week_number = current_week 
        AND year = current_year
    ) THEN
        -- Get random active theme
        SELECT * INTO theme 
        FROM challenge_themes 
        WHERE is_active = TRUE 
        ORDER BY RANDOM() 
        LIMIT 1;

        -- Insert into automatic_challenges
        INSERT INTO automatic_challenges (
            theme_id,
            week_number,
            year,
            status
        ) VALUES (
            theme.id,
            current_week,
            current_year,
            'pending'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add function to create challenge from automatic generation
CREATE OR REPLACE FUNCTION create_challenge_from_generation()
RETURNS void AS $$
DECLARE
    generation automatic_challenges%ROWTYPE;
    theme challenge_themes%ROWTYPE;
BEGIN
    -- Get pending generation
    SELECT * INTO generation 
    FROM automatic_challenges 
    WHERE status = 'pending' 
    ORDER BY created_at 
    LIMIT 1;

    IF FOUND THEN
        -- Get theme
        SELECT * INTO theme 
        FROM challenge_themes 
        WHERE id = generation.theme_id;

        -- Create challenge
        INSERT INTO challenges (
            title,
            description,
            theme,
            status,
            start_date,
            end_date,
            reward_lolcoins,
            is_active
        ) VALUES (
            theme.name,
            theme.description,
            theme.name,
            'active',
            now(),
            now() + INTERVAL '7 days',
            500,
            TRUE
        ) RETURNING id INTO generation.challenge_id;

        -- Update generation status
        UPDATE automatic_challenges 
        SET status = 'completed',
            updated_at = now()
        WHERE id = generation.id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Add function to process challenge results
CREATE OR REPLACE FUNCTION process_challenge_results()
RETURNS void AS $$
DECLARE
    challenge challenges%ROWTYPE;
    rankings RECORD;
BEGIN
    -- Get completed challenges
    FOR challenge IN 
        SELECT * FROM challenges 
        WHERE status = 'completed' 
        AND end_date < now()
    LOOP
        -- Calculate rankings
        FOR rankings IN 
            SELECT 
                user_id,
                meme_id,
                total_likes,
                rank
            FROM calculate_challenge_rankings(challenge.id)
        LOOP
            -- Add reward to creator
            INSERT INTO lolcoin_transactions (
                user_id,
                type,
                amount,
                description
            ) VALUES (
                rankings.user_id,
                'reward_challenge',
                calculateChallengeRewards(rankings.rank),
                format('Challenge %s reward (Rank %s)', challenge.id, rankings.rank)
            );

            -- Update user's LOLCoins
            UPDATE users 
            SET lolcoins_earned = lolcoins_earned + calculateChallengeRewards(rankings.rank),
                updated_at = now()
            WHERE id = rankings.user_id;

            -- Create notification for winners
            IF rankings.rank <= 3 THEN
                INSERT INTO notifications (
                    user_id,
                    type,
                    title,
                    message,
                    data
                ) VALUES (
                    rankings.user_id,
                    'challenge_won',
                    'Challenge Won!',
                    format('You won Rank %s in challenge %s!', rankings.rank, challenge.title),
                    jsonb_build_object(
                        'challenge_id', challenge.id,
                        'rank', rankings.rank,
                        'reward', calculateChallengeRewards(rankings.rank)
                    )
                );
            END IF;
        END LOOP;

        -- Update challenge status
        UPDATE challenges 
        SET status = 'completed',
            updated_at = now()
        WHERE id = challenge.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Add function to send challenge reminders
CREATE OR REPLACE FUNCTION send_challenge_reminders()
RETURNS void AS $$
DECLARE
    challenge challenges%ROWTYPE;
    user users%ROWTYPE;
BEGIN
    -- Get active challenges ending in 24 hours
    FOR challenge IN 
        SELECT * FROM challenges 
        WHERE status = 'active' 
        AND end_date BETWEEN now() AND now() + INTERVAL '24 hours'
    LOOP
        -- Get all participants
        FOR user IN 
            SELECT DISTINCT user_id 
            FROM meme_challenge_participations 
            WHERE challenge_id = challenge.id
        LOOP
            INSERT INTO notifications (
                user_id,
                type,
                title,
                message,
                data
            ) VALUES (
                user.id,
                'challenge_reminder',
                'Challenge Ending Soon',
                format('Challenge %s ends in less than 24 hours!', challenge.title),
                jsonb_build_object(
                    'challenge_id', challenge.id,
                    'end_date', challenge.end_date
                )
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
