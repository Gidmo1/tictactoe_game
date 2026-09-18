ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS tournament_match_code TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_tournament_match_code
  ON public.matches (tournament_match_code)
  WHERE tournament_match_code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.start_or_join_tournament_match(
  target_tournament_id UUID,
  target_tournament_match_id TEXT,
  target_board_size INT,
  target_win_length INT,
  target_opponent_id UUID DEFAULT NULL
)
RETURNS public.matches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  canonical_code TEXT;
  existing_match public.matches;
  created_match public.matches;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  canonical_code := upper(
    trim(
      'T' || replace(target_tournament_id::text, '-', '') ||
      replace(coalesce(target_tournament_match_id, ''), '-', '')
    )
  );

  IF length(canonical_code) > 12 THEN
    canonical_code := left(canonical_code, 12);
  END IF;

  SELECT * INTO existing_match
  FROM public.matches
  WHERE tournament_match_code = canonical_code
  FOR UPDATE;

  IF existing_match.id IS NOT NULL THEN
    IF existing_match.player_x = auth.uid() OR existing_match.player_o = auth.uid() THEN
      RETURN existing_match;
    END IF;

    IF existing_match.status = 'waiting' AND existing_match.player_o IS NULL THEN
      UPDATE public.matches
      SET player_o = auth.uid(),
          status = 'active',
          updated_at = now()
      WHERE id = existing_match.id
      RETURNING * INTO existing_match;
      RETURN existing_match;
    END IF;

    RETURN existing_match;
  END IF;

  INSERT INTO public.matches (
    invite_code,
    tournament_id,
    tournament_match_id,
    tournament_match_code,
    player_x,
    player_o,
    board_size,
    win_length,
    board,
    current_turn,
    status,
    created_at,
    updated_at
  )
  SELECT
    canonical_code,
    target_tournament_id,
    target_tournament_match_id,
    canonical_code,
    auth.uid(),
    target_opponent_id,
    target_board_size,
    target_win_length,
    jsonb_agg(jsonb_agg(''::text ORDER BY col_num) ORDER BY row_num),
    'X',
    CASE WHEN target_opponent_id IS NULL THEN 'waiting' ELSE 'active' END,
    now(),
    now()
  FROM (
    SELECT row_num, col_num
    FROM generate_series(0, target_board_size - 1) AS row_num
    CROSS JOIN generate_series(0, target_board_size - 1) AS col_num
  ) s
  GROUP BY row_num
  ORDER BY row_num
  RETURNING * INTO created_match;

  RETURN created_match;
END;
$$;

REVOKE ALL ON FUNCTION public.start_or_join_tournament_match(UUID, TEXT, INT, INT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_or_join_tournament_match(UUID, TEXT, INT, INT, UUID) TO authenticated;
