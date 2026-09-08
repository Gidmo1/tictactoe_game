-- Runtime support for private tournaments and synchronized tournament matches.
-- Run after 20240001_create_tournaments.sql.
-- This migration upgrades public.matches in place and preserves every row and column.

-- 1. Add created_by, 2. backfill it, and 3-5. validate and constrain it.
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS created_by UUID;

UPDATE public.matches
SET created_by = player_x
WHERE created_by IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.matches
    WHERE created_by IS NULL
  ) THEN
    RAISE EXCEPTION 'Cannot backfill matches.created_by: existing rows have no player_x';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.matches m
    LEFT JOIN public.profiles p ON p.id = m.player_x
    WHERE m.player_x IS NOT NULL
      AND p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Cannot backfill matches.created_by: one or more player_x values do not exist in public.profiles(id)';
  END IF;
END $$;

DO $$
DECLARE
  created_by_attnum smallint;
BEGIN
  SELECT attnum INTO created_by_attnum
  FROM pg_attribute
  WHERE attrelid = 'public.matches'::regclass
    AND attname = 'created_by'
    AND NOT attisdropped;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.matches'::regclass
      AND contype = 'f'
      AND confrelid = 'public.profiles'::regclass
      AND conkey = ARRAY[created_by_attnum]::smallint[]
  ) THEN
    NULL;
  ELSIF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.matches'::regclass
      AND contype = 'f'
      AND conkey = ARRAY[created_by_attnum]::smallint[]
  ) THEN
    RAISE EXCEPTION 'An existing matches.created_by foreign key references a table other than public.profiles(id)';
  ELSE
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_created_by_fkey
      FOREIGN KEY (created_by) REFERENCES public.profiles(id);
  END IF;
END $$;

ALTER TABLE public.matches ALTER COLUMN created_by SET NOT NULL;

-- Add the unique invite-code constraint only after reporting duplicates clearly.
DO $$
DECLARE
  invite_code_attnum smallint;
BEGIN
  SELECT attnum INTO invite_code_attnum
  FROM pg_attribute
  WHERE attrelid = 'public.matches'::regclass
    AND attname = 'invite_code'
    AND NOT attisdropped;

  IF EXISTS (
    SELECT invite_code
    FROM public.matches
    WHERE invite_code IS NOT NULL
    GROUP BY invite_code
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Cannot add unique invite_code constraint: duplicate non-NULL invite codes exist';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = 'public.matches'::regclass
      AND i.indisunique
      AND i.indnkeyatts = 1
      AND i.indkey[0] = invite_code_attnum
  ) THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_invite_code_key UNIQUE (invite_code);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_matches_invite_code ON public.matches(invite_code);
CREATE INDEX IF NOT EXISTS idx_matches_players ON public.matches(player_x, player_o);

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "match_participants_can_read" ON public.matches;
CREATE POLICY "match_participants_can_read" ON public.matches
  FOR SELECT
  USING (auth.uid() = created_by OR auth.uid() = player_x OR auth.uid() = player_o);

-- Gameplay state is changed only through the SECURITY DEFINER RPCs below.
REVOKE UPDATE ON public.matches FROM anon, authenticated;
DROP POLICY IF EXISTS "match_participants_can_update" ON public.matches;

CREATE OR REPLACE FUNCTION public.create_match(
  match_board_size INT DEFAULT 3,
  match_win_length INT DEFAULT 3,
  match_opponent_id UUID DEFAULT NULL,
  match_invite_code TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  new_match public.matches;
  code TEXT := COALESCE(
    NULLIF(upper(match_invite_code), ''),
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  );
  empty_board JSONB;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF match_opponent_id = auth.uid() THEN RAISE EXCEPTION 'Cannot play against yourself'; END IF;
  IF match_board_size NOT BETWEEN 3 AND 5 THEN RAISE EXCEPTION 'Invalid board size'; END IF;
  IF match_win_length NOT BETWEEN 3 AND match_board_size THEN RAISE EXCEPTION 'Invalid win length'; END IF;

  SELECT jsonb_agg(row_values ORDER BY row_number)
  INTO empty_board
  FROM (
    SELECT row_number,
           jsonb_agg('""'::jsonb ORDER BY column_number) AS row_values
    FROM generate_series(0, match_board_size - 1) AS rows(row_number)
    CROSS JOIN generate_series(0, match_board_size - 1) AS columns(column_number)
    GROUP BY row_number
  ) board_rows;

  INSERT INTO public.matches (
    invite_code, created_by, player_x, player_o, board_size, win_length, board, status
  )
  VALUES (
    code, auth.uid(), auth.uid(), match_opponent_id, match_board_size, match_win_length,
    empty_board, CASE WHEN match_opponent_id IS NULL THEN 'waiting' ELSE 'active' END
  )
  RETURNING * INTO new_match;

  RETURN jsonb_build_object(
    'id', new_match.id,
    'invite_code', new_match.invite_code,
    'player_x', new_match.player_x,
    'player_o', new_match.player_o,
    'board_size', new_match.board_size,
    'win_length', new_match.win_length,
    'status', new_match.status
  );
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Invite code already exists';
END;
$$;

CREATE OR REPLACE FUNCTION public.join_match(target_match_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  target public.matches;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO target
  FROM public.matches
  WHERE id::text = target_match_code OR upper(invite_code) = upper(target_match_code)
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;
  IF target.player_x = auth.uid() OR target.player_o = auth.uid() THEN RETURN to_jsonb(target); END IF;
  IF target.player_o IS NOT NULL OR target.status <> 'waiting' THEN RAISE EXCEPTION 'Match is not available'; END IF;

  UPDATE public.matches
  SET player_o = auth.uid(), status = 'active', updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;
  RETURN to_jsonb(target);
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_move(
  target_match_id UUID,
  move_row INT,
  move_col INT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  target public.matches;
  symbol TEXT;
  next_board JSONB;
  row_values JSONB;
  winner_uid UUID := NULL;
  has_win BOOLEAN := false;
  is_draw BOOLEAN := true;
  r INT;
  c INT;
  line_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO target FROM public.matches WHERE id = target_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Match not found'; END IF;
  IF target.status <> 'active' THEN RAISE EXCEPTION 'Match is not active'; END IF;
  IF auth.uid() = target.player_x THEN symbol := 'X';
  ELSIF auth.uid() = target.player_o THEN symbol := 'O';
  ELSE RAISE EXCEPTION 'You are not a player in this match'; END IF;
  IF target.current_turn <> symbol THEN RAISE EXCEPTION 'It is not your turn'; END IF;
  IF move_row < 0 OR move_row >= target.board_size OR move_col < 0 OR move_col >= target.board_size THEN
    RAISE EXCEPTION 'Move is outside the board';
  END IF;

  IF target.board IS NULL OR jsonb_typeof(target.board) <> 'array' THEN
    RAISE EXCEPTION 'Match board is malformed: expected a JSON array';
  END IF;
  IF jsonb_array_length(target.board) <> target.board_size THEN
    RAISE EXCEPTION 'Match board is malformed: expected % rows', target.board_size;
  END IF;

  FOR r IN 0..target.board_size - 1 LOOP
    IF jsonb_typeof(target.board -> r) <> 'array' THEN
      RAISE EXCEPTION 'Match board is malformed: expected a % by % grid', target.board_size, target.board_size;
    END IF;
    IF jsonb_array_length(target.board -> r) <> target.board_size THEN
      RAISE EXCEPTION 'Match board is malformed: expected a % by % grid', target.board_size, target.board_size;
    END IF;
    FOR c IN 0..target.board_size - 1 LOOP
      IF jsonb_typeof(target.board -> r -> c) <> 'string' THEN
        RAISE EXCEPTION 'Match board is malformed: every cell must be a string';
      END IF;
      IF target.board -> r ->> c NOT IN ('', 'X', 'O') THEN
        RAISE EXCEPTION 'Match board is malformed: cells may only contain empty strings, X, or O';
      END IF;
    END LOOP;
  END LOOP;

  IF target.board -> move_row ->> move_col <> '' THEN
    RAISE EXCEPTION 'Cell is already occupied';
  END IF;

  row_values := jsonb_set(target.board -> move_row, ARRAY[move_col::text], to_jsonb(symbol), false);
  next_board := jsonb_set(target.board, ARRAY[move_row::text], row_values, false);

  FOR r IN 0..target.board_size - 1 LOOP
    FOR c IN 0..target.board_size - 1 LOOP
      IF next_board -> r ->> c = '' THEN
        is_draw := false;
      ELSIF next_board -> r ->> c = symbol THEN
        IF c + target.win_length <= target.board_size THEN
          SELECT count(*) INTO line_count
          FROM generate_series(0, target.win_length - 1) i
          WHERE next_board -> r ->> (c + i) = symbol;
          IF line_count = target.win_length THEN has_win := true; END IF;
        END IF;
        IF r + target.win_length <= target.board_size THEN
          SELECT count(*) INTO line_count
          FROM generate_series(0, target.win_length - 1) i
          WHERE next_board -> (r + i) ->> c = symbol;
          IF line_count = target.win_length THEN has_win := true; END IF;
        END IF;
        IF r + target.win_length <= target.board_size
           AND c + target.win_length <= target.board_size THEN
          SELECT count(*) INTO line_count
          FROM generate_series(0, target.win_length - 1) i
          WHERE next_board -> (r + i) ->> (c + i) = symbol;
          IF line_count = target.win_length THEN has_win := true; END IF;
        END IF;
        IF r + target.win_length <= target.board_size
           AND c - target.win_length + 1 >= 0 THEN
          SELECT count(*) INTO line_count
          FROM generate_series(0, target.win_length - 1) i
          WHERE next_board -> (r + i) ->> (c - i) = symbol;
          IF line_count = target.win_length THEN has_win := true; END IF;
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  IF has_win THEN winner_uid := auth.uid(); END IF;

  UPDATE public.matches SET
    board = next_board,
    move_number = target.move_number + 1,
    current_turn = CASE
      WHEN has_win OR is_draw THEN target.current_turn
      WHEN symbol = 'X' THEN 'O'
      ELSE 'X'
    END,
    status = CASE WHEN has_win OR is_draw THEN 'finished' ELSE 'active' END,
    winner = winner_uid,
    finished_at = CASE WHEN has_win OR is_draw THEN now() ELSE target.finished_at END,
    updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN to_jsonb(target);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_match(INT, INT, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.join_match(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_move(UUID, INT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_match(INT, INT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_match(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_move(UUID, INT, INT) TO authenticated;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tournaments;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- Archive waiting tournaments through the app's guarded cancellation method.
DROP POLICY IF EXISTS "users_can_delete_tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "users_can_update_tournaments" ON public.tournaments;
CREATE POLICY "users_can_update_tournaments" ON public.tournaments
  FOR UPDATE
  USING (auth.uid()::text = created_by::text)
  WITH CHECK (auth.uid()::text = created_by::text);
DROP POLICY IF EXISTS "users_can_create_tournaments" ON public.tournaments;
CREATE POLICY "users_can_create_tournaments" ON public.tournaments
  FOR INSERT
  WITH CHECK (auth.uid()::text = created_by::text);

CREATE OR REPLACE FUNCTION public.touch_tournament_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tournaments_updated_at ON public.tournaments;
CREATE TRIGGER tournaments_updated_at
  BEFORE UPDATE ON public.tournaments
  FOR EACH ROW EXECUTE FUNCTION public.touch_tournament_updated_at();
