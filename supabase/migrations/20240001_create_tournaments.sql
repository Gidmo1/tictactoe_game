-- Create tournaments table
CREATE TABLE tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('private', 'official')),
  status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'completed', 'cancelled')),
  created_by UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW() NOT NULL,
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  invite_code TEXT UNIQUE,
  max_participants INT NOT NULL CHECK (max_participants >= 2 AND max_participants <= 16),
  participants TEXT[] NOT NULL DEFAULT '{}',
  bracket_type TEXT NOT NULL DEFAULT 'singleElimination' CHECK (bracket_type IN ('singleElimination', 'doubleElimination', 'roundRobin')),
  grid_size TEXT NOT NULL DEFAULT 'small' CHECK (grid_size IN ('small', 'medium', 'large')),
  description TEXT,
  bracket JSONB DEFAULT '{}',
  winner_uid TEXT,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX idx_tournaments_type_status ON tournaments(type, status);
CREATE INDEX idx_tournaments_invite_code ON tournaments(invite_code);
CREATE INDEX idx_tournaments_created_by ON tournaments(created_by);
CREATE INDEX idx_tournaments_participants ON tournaments USING GIN(participants);
CREATE INDEX idx_tournaments_created_at ON tournaments(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Anyone can read tournaments
CREATE POLICY "anyone_can_read_tournaments" ON tournaments
  FOR SELECT
  USING (true);

-- Users can create tournaments
CREATE POLICY "users_can_create_tournaments" ON tournaments
  FOR INSERT
  WITH CHECK (true);

-- Users can update tournaments
CREATE POLICY "users_can_update_tournaments" ON tournaments
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Delete policy
CREATE POLICY "users_can_delete_tournaments" ON tournaments
  FOR DELETE
  USING (true);
