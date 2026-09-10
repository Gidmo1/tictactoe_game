-- Tournament rules v2.
--
-- The original tournament implementation let clients read/modify the whole
-- participant list and bracket. This migration moves membership, starting,
-- matchmaking, and result transitions behind locked SECURITY DEFINER RPCs.

ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS format TEXT;

UPDATE public.tournaments
SET format = CASE
  WHEN type = 'official' THEN 'liveMatchmaking'
  ELSE 'flexibleBracket'
END
WHERE format IS NULL;

ALTER TABLE public.tournaments
  ALTER COLUMN format SET DEFAULT 'flexibleBracket',
  ALTER COLUMN format SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tournaments'::regclass
      AND conname = 'tournaments_format_check'
  ) THEN
    ALTER TABLE public.tournaments
      ADD CONSTRAINT tournaments_format_check
      CHECK (format IN ('liveMatchmaking', 'cup', 'flexibleBracket'));
  END IF;
END $$;

ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS round_deadline_hours INT NOT NULL DEFAULT 48,
  ADD COLUMN IF NOT EXISTS participants_locked_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.tournaments'::regclass
      AND conname = 'tournaments_round_deadline_hours_check'
  ) THEN
    ALTER TABLE public.tournaments
      ADD CONSTRAINT tournaments_round_deadline_hours_check
      CHECK (round_deadline_hours BETWEEN 1 AND 168);
  END IF;
END $$;

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS tournament_id UUID
    REFERENCES public.tournaments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tournament_match_id TEXT;

CREATE INDEX IF NOT EXISTS idx_matches_tournament
  ON public.matches(tournament_id, tournament_match_id);

CREATE TABLE IF NOT EXISTS public.tournament_matchmaking_queue (
  tournament_id UUID NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tournament_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_tournament_matchmaking_queue_order
  ON public.tournament_matchmaking_queue(tournament_id, joined_at);

ALTER TABLE public.tournament_matchmaking_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_can_read_own_tournament_queue"
  ON public.tournament_matchmaking_queue;
CREATE POLICY "users_can_read_own_tournament_queue"
  ON public.tournament_matchmaking_queue
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.join_tournament(target_invite_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target public.tournaments;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO target
  FROM public.tournaments
  WHERE upper(invite_code) = upper(trim(target_invite_code))
    AND type = 'private'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tournament not found';
  END IF;

  IF target.status <> 'waiting' OR target.participants_locked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Tournament registration is closed';
  END IF;

  IF auth.uid()::TEXT = ANY(COALESCE(target.participants, ARRAY[]::TEXT[])) THEN
    RETURN to_jsonb(target);
  END IF;

  IF cardinality(COALESCE(target.participants, ARRAY[]::TEXT[]))
      >= target.max_participants THEN
    RAISE EXCEPTION 'Tournament is full';
  END IF;

  UPDATE public.tournaments
  SET participants = array_append(
        COALESCE(participants, ARRAY[]::TEXT[]),
        auth.uid()::TEXT
      ),
      updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN to_jsonb(target);
END;
$$;
REVOKE ALL ON FUNCTION public.join_tournament(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_tournament(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.register_tournament_participant(
  target_tournament_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target public.tournaments;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO target
  FROM public.tournaments
  WHERE id = target_tournament_id
    AND type = 'official'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Official tournament not found';
  END IF;
  IF target.status <> 'waiting' OR target.participants_locked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Tournament registration is closed';
  END IF;
  IF auth.uid()::TEXT = ANY(COALESCE(target.participants, ARRAY[]::TEXT[])) THEN
    RETURN to_jsonb(target);
  END IF;
  IF cardinality(COALESCE(target.participants, ARRAY[]::TEXT[]))
      >= target.max_participants THEN
    RAISE EXCEPTION 'Tournament is full';
  END IF;

  UPDATE public.tournaments
  SET participants = array_append(
        COALESCE(participants, ARRAY[]::TEXT[]),
        auth.uid()::TEXT
      ),
      updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN to_jsonb(target);
END;
$$;
REVOKE ALL ON FUNCTION public.register_tournament_participant(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_tournament_participant(UUID)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.start_tournament(
  target_tournament_id UUID,
  target_bracket JSONB,
  target_round_deadline_hours INT DEFAULT 48,
  expected_updated_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target public.tournaments;
  participant TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO target
  FROM public.tournaments
  WHERE id = target_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Tournament not found'; END IF;
  IF target.created_by <> auth.uid() THEN
    RAISE EXCEPTION 'Only the tournament host can start it';
  END IF;
  IF NOT (
    (target.type = 'private' AND target.format = 'flexibleBracket')
    OR (target.type = 'official' AND target.format = 'cup')
  ) THEN
    RAISE EXCEPTION 'Tournament format cannot be started here';
  END IF;
  IF target.status <> 'waiting' OR target.participants_locked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Tournament has already started';
  END IF;
  IF expected_updated_at IS NOT NULL
     AND target.updated_at <> expected_updated_at THEN
    RAISE EXCEPTION 'Tournament changed while it was being started';
  END IF;
  IF cardinality(COALESCE(target.participants, ARRAY[]::TEXT[])) < 2 THEN
    RAISE EXCEPTION 'At least two players are required';
  END IF;
  IF target_round_deadline_hours NOT BETWEEN 1 AND 168 THEN
    RAISE EXCEPTION 'Invalid round deadline';
  END IF;
  IF jsonb_typeof(target_bracket) <> 'object'
     OR jsonb_typeof(target_bracket -> 'round_1') <> 'array' THEN
    RAISE EXCEPTION 'Bracket is malformed';
  END IF;

  -- Every registered player must appear in round one. This prevents a client
  -- from silently dropping a joined player when it generates the bracket.
  FOREACH participant IN ARRAY COALESCE(target.participants, ARRAY[]::TEXT[])
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(target_bracket -> 'round_1') AS match
      WHERE participant = (match ->> 'player1')
         OR participant = (match ->> 'player2')
    ) THEN
      RAISE EXCEPTION 'Bracket does not contain every participant';
    END IF;
  END LOOP;

  UPDATE public.tournaments
  SET status = 'active',
      start_time = now(),
      participants_locked_at = now(),
      round_deadline_hours = target_round_deadline_hours,
      bracket = target_bracket,
      updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN to_jsonb(target);
END;
$$;
REVOKE ALL ON FUNCTION public.start_tournament(UUID, JSONB, INT, TIMESTAMPTZ)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_tournament(UUID, JSONB, INT, TIMESTAMPTZ)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_tournament_match(
  target_tournament_id UUID,
  target_match_id TEXT,
  target_winner_uid UUID,
  target_bracket JSONB,
  is_forfeit BOOLEAN DEFAULT FALSE,
  expected_updated_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target public.tournaments;
  round_entry RECORD;
  match_index INT;
  candidate JSONB;
  old_match JSONB;
  updated_match JSONB;
  old_round_key TEXT;
  old_match_index INT;
  player_id TEXT;
  final_round_key TEXT;
  final_match JSONB;
  final_round_number INT := 0;
  current_round_number INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO target
  FROM public.tournaments
  WHERE id = target_tournament_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Tournament not found'; END IF;
  IF target.status <> 'active'
     OR target.format NOT IN ('cup', 'flexibleBracket') THEN
    RAISE EXCEPTION 'Tournament is not an active bracket';
  END IF;
  IF expected_updated_at IS NOT NULL
     AND target.updated_at <> expected_updated_at THEN
    RAISE EXCEPTION 'Tournament changed; refresh before submitting the result';
  END IF;

  -- Locate the server's current version of the match.
  FOR round_entry IN
    SELECT key, value
    FROM jsonb_each(target.bracket)
    WHERE key LIKE 'round_%'
  LOOP
    IF jsonb_typeof(round_entry.value) <> 'array' THEN CONTINUE; END IF;
    FOR match_index IN 0..jsonb_array_length(round_entry.value) - 1
    LOOP
      candidate := round_entry.value -> match_index;
      IF candidate ->> 'id' = target_match_id THEN
        old_match := candidate;
        old_round_key := round_entry.key;
        old_match_index := match_index;
      END IF;
    END LOOP;
  END LOOP;

  IF old_match IS NULL THEN RAISE EXCEPTION 'Tournament match not found'; END IF;
  IF old_match ->> 'completed' = 'true' THEN
    RAISE EXCEPTION 'Tournament match is already complete';
  END IF;
  IF old_match ->> 'player1' IS NULL OR old_match ->> 'player2' IS NULL THEN
    RAISE EXCEPTION 'Tournament match is not ready';
  END IF;
  IF auth.uid()::TEXT NOT IN (old_match ->> 'player1', old_match ->> 'player2')
     OR target_winner_uid::TEXT NOT IN (old_match ->> 'player1', old_match ->> 'player2') THEN
    RAISE EXCEPTION 'You are not authorized to submit this result';
  END IF;
  IF is_forfeit AND (
    old_match ->> 'deadline' IS NULL
    OR now() <= (old_match ->> 'deadline')::TIMESTAMPTZ
  ) THEN
    RAISE EXCEPTION 'The round deadline has not passed';
  END IF;

  updated_match := target_bracket -> old_round_key -> old_match_index;
  IF updated_match IS NULL
     OR (updated_match ->> 'id') <> target_match_id
     OR (updated_match ->> 'completed') <> 'true'
     OR (updated_match ->> 'winner') <> target_winner_uid::TEXT
     OR (updated_match ->> 'player1') <> (old_match ->> 'player1')
     OR (updated_match ->> 'player2') <> (old_match ->> 'player2') THEN
    RAISE EXCEPTION 'Submitted bracket does not contain a valid result';
  END IF;

  -- No player outside the locked participant list may be introduced by a
  -- client-generated advancement.
  FOR round_entry IN
    SELECT key, value
    FROM jsonb_each(target_bracket)
    WHERE key LIKE 'round_%'
  LOOP
    IF jsonb_typeof(round_entry.value) <> 'array' THEN CONTINUE; END IF;
    FOR match_index IN 0..jsonb_array_length(round_entry.value) - 1
    LOOP
      candidate := round_entry.value -> match_index;
      FOREACH player_id IN ARRAY ARRAY[
        candidate ->> 'player1',
        candidate ->> 'player2',
        candidate ->> 'winner'
      ]
      LOOP
        IF player_id IS NOT NULL
           AND player_id <> ''
           AND NOT (player_id = ANY(COALESCE(target.participants, ARRAY[]::TEXT[]))) THEN
          RAISE EXCEPTION 'Bracket contains an unregistered player';
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  -- Determine whether the submitted state has completed the final match.
  FOR round_entry IN
    SELECT key, value
    FROM jsonb_each(target_bracket)
    WHERE key LIKE 'round_%'
  LOOP
    current_round_number :=
      COALESCE(NULLIF(replace(round_entry.key, 'round_', ''), ''), '0')::INT;
    IF current_round_number > final_round_number THEN
      final_round_number := current_round_number;
      final_round_key := round_entry.key;
    END IF;
  END LOOP;
  final_match := target_bracket -> final_round_key -> 0;

  UPDATE public.tournaments
  SET bracket = target_bracket,
      status = CASE
        WHEN final_match ->> 'completed' = 'true'
         AND final_match ->> 'winner' IS NOT NULL
        THEN 'completed'
        ELSE 'active'
      END,
      winner_uid = CASE
        WHEN final_match ->> 'completed' = 'true'
        THEN (final_match ->> 'winner')::UUID
        ELSE NULL
      END,
      end_time = CASE
        WHEN final_match ->> 'completed' = 'true' THEN now()
        ELSE NULL
      END,
      updated_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN to_jsonb(target);
END;
$$;
REVOKE ALL ON FUNCTION public.complete_tournament_match(
  UUID, TEXT, UUID, JSONB, BOOLEAN, TIMESTAMPTZ
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_tournament_match(
  UUID, TEXT, UUID, JSONB, BOOLEAN, TIMESTAMPTZ
) TO authenticated;

CREATE OR REPLACE FUNCTION public.join_official_matchmaking(
  target_tournament_id UUID,
  match_board_size INT,
  match_win_length INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target public.tournaments;
  opponent_id UUID;
  new_match public.matches;
  empty_board JSONB;
  waiting_user public.tournament_matchmaking_queue;
  generated_code TEXT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF match_board_size NOT BETWEEN 3 AND 5
     OR match_win_length NOT BETWEEN 3 AND match_board_size THEN
    RAISE EXCEPTION 'Invalid board settings';
  END IF;

  SELECT *
  INTO target
  FROM public.tournaments
  WHERE id = target_tournament_id
    AND type = 'official'
    AND format = 'liveMatchmaking'
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Official live tournament not found'; END IF;
  IF target.status <> 'active' THEN
    RAISE EXCEPTION 'Official tournament is not live';
  END IF;
  IF NOT (auth.uid()::TEXT = ANY(COALESCE(target.participants, ARRAY[]::TEXT[]))) THEN
    RAISE EXCEPTION 'Register for the tournament before matchmaking';
  END IF;

  SELECT *
  INTO waiting_user
  FROM public.tournament_matchmaking_queue
  WHERE tournament_id = target.id
    AND user_id <> auth.uid()
  ORDER BY joined_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF waiting_user.user_id IS NULL THEN
    INSERT INTO public.tournament_matchmaking_queue(tournament_id, user_id)
    VALUES (target.id, auth.uid())
    ON CONFLICT (tournament_id, user_id)
    DO UPDATE SET joined_at = now();
    RETURN jsonb_build_object('status', 'queued', 'tournament_id', target.id);
  END IF;

  opponent_id := waiting_user.user_id;
  DELETE FROM public.tournament_matchmaking_queue
  WHERE tournament_id = target.id
    AND user_id IN (auth.uid(), opponent_id);

  SELECT jsonb_agg(row_values ORDER BY row_number)
  INTO empty_board
  FROM (
    SELECT row_number,
           jsonb_agg('""'::JSONB ORDER BY column_number) AS row_values
    FROM generate_series(0, match_board_size - 1) AS rows(row_number)
    CROSS JOIN generate_series(0, match_board_size - 1) AS columns(column_number)
    GROUP BY row_number
  ) board_rows;

  generated_code := upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8));
  INSERT INTO public.matches (
    invite_code,
    created_by,
    player_x,
    player_o,
    board_size,
    win_length,
    board,
    status,
    tournament_id
  )
  VALUES (
    generated_code,
    opponent_id,
    opponent_id,
    auth.uid(),
    match_board_size,
    match_win_length,
    empty_board,
    'active',
    target.id
  )
  RETURNING * INTO new_match;

  RETURN jsonb_build_object(
    'status', 'matched',
    'tournament_id', target.id,
    'match', to_jsonb(new_match)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.join_official_matchmaking(UUID, INT, INT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_official_matchmaking(UUID, INT, INT)
  TO authenticated;