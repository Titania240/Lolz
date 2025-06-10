-- Create withdrawals table
CREATE TABLE IF NOT EXISTS withdrawals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    request_amount INTEGER NOT NULL,
    fees INTEGER DEFAULT 700,
    final_amount INTEGER GENERATED ALWAYS AS (request_amount - fees) STORED,
    method TEXT CHECK (method IN ('mobile_money', 'bank', 'paypal')),
    payment_info JSONB,
    status TEXT CHECK (status IN ('pending', 'valid', 'refused', 'completed')) DEFAULT 'pending',
    request_date TIMESTAMP DEFAULT now(),
    processing_date TIMESTAMP,
    admin_note TEXT,
    admin_id UUID REFERENCES users(id),
    processed_by TEXT,
    CONSTRAINT positive_amount CHECK (request_amount > 0),
    CONSTRAINT min_amount CHECK (request_amount >= 2000),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'valid', 'refused', 'completed'))
);

-- Create index for faster queries
CREATE INDEX idx_withdrawals_user_id ON withdrawals(user_id);
CREATE INDEX idx_withdrawals_status ON withdrawals(status);
CREATE INDEX idx_withdrawals_request_date ON withdrawals(request_date);

-- Add foreign key constraint for admin_id
ALTER TABLE withdrawals 
ADD CONSTRAINT fk_withdrawals_admin 
FOREIGN KEY (admin_id) REFERENCES users(id);

-- Add trigger to update processed_by when admin_id is set
CREATE OR REPLACE FUNCTION update_processed_by()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.admin_id IS NOT NULL THEN
        NEW.processed_by = (SELECT email FROM users WHERE id = NEW.admin_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_processed_by_trigger
BEFORE UPDATE ON withdrawals
FOR EACH ROW
EXECUTE FUNCTION update_processed_by();
