-- Supabase Phase 1 schema for Tic Tac Toe
-- Paste this entire file into the Supabase SQL Editor and run it once.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  avatar_id text,
  tier text not null default 'bronze' check (tier in ('bronze', 'silver', 'gold', 'platinum', 'diamond')),
  rating integer not null default 1000 check (rating >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  draws integer not null default 0 check (draws >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are publicly readable" on public.profiles;
create policy "Profiles are publicly readable"
  on public.profiles for select using (true);

drop policy if exists "Users can insert their profile" on public.profiles;
create policy "Users can insert their profile"
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile"
  on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Users can delete their profile" on public.profiles;
create policy "Users can delete their profile"
  on public.profiles for delete using (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'user_name', new.raw_user_meta_data ->> 'name')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

create table if not exists public.scores (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  result text not null check (result in ('win', 'loss', 'draw')),
  points integer not null default 0 check (points >= 0),
  board_size integer not null default 3 check (board_size between 3 and 10),
  opponent_type text not null default 'computer',
  created_at timestamptz not null default now()
);

create index if not exists scores_player_id_created_at_idx
  on public.scores (player_id, created_at desc);

alter table public.scores enable row level security;

drop policy if exists "Players can read their scores" on public.scores;
create policy "Players can read their scores"
  on public.scores for select using (auth.uid() = player_id);

create or replace function public.record_score(
  score_result text,
  score_points integer default 0,
  score_board_size integer default 3,
  score_opponent_type text default 'computer'
)
returns public.profiles
language plpgsql
security definer set search_path = public
as $$
declare
  updated_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if score_result not in ('win', 'loss', 'draw') then
    raise exception 'invalid score result';
  end if;

  insert into public.scores (player_id, result, points, board_size, opponent_type)
  values (auth.uid(), score_result, greatest(score_points, 0), score_board_size, score_opponent_type);

  update public.profiles
  set wins = wins + case when score_result = 'win' then 1 else 0 end,
      losses = losses + case when score_result = 'loss' then 1 else 0 end,
      draws = draws + case when score_result = 'draw' then 1 else 0 end,
      rating = greatest(0, rating + case when score_result = 'win' then 25 when score_result = 'loss' then -15 else 5 end)
  where id = auth.uid()
  returning * into updated_profile;

  return updated_profile;
end;
$$;

revoke all on function public.record_score(text, integer, integer, text) from public;
grant execute on function public.record_score(text, integer, integer, text) to authenticated;

-- Online match foundation
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique,
  player_x uuid not null references public.profiles(id),
  player_o uuid references public.profiles(id),
  board_size integer not null default 3 check (board_size between 3 and 10),
  win_length integer not null check (win_length between 3 and 5),
  board jsonb not null,
  current_turn text not null default 'X' check (current_turn in ('X', 'O')),
  status text not null default 'waiting' check (status in ('waiting', 'active', 'finished', 'abandoned')),
  winner uuid references public.profiles(id),
  move_number integer not null default 0 check (move_number >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finished_at timestamptz
);

-- Migrate matches created before invite codes were introduced.
alter table public.matches add column if not exists invite_code text;
update public.matches
set invite_code = upper(substr(md5(id::text), 1, 8))
where invite_code is null or trim(invite_code) = '';
create unique index if not exists matches_invite_code_idx
  on public.matches (invite_code);
alter table public.matches alter column invite_code set not null;

alter table public.matches enable row level security;

drop policy if exists "Participants can read matches" on public.matches;
create policy "Participants can read matches"
  on public.matches for select
  using (auth.uid() = player_x or auth.uid() = player_o);

create or replace function public.create_match(
  match_board_size integer,
  match_win_length integer,
  match_opponent_id uuid default null,
  match_invite_code text default null
)
returns public.matches
language plpgsql
security definer set search_path = public
as $$
declare
  new_match public.matches;
  empty_board jsonb := '[]'::jsonb;
  i integer;
  generated_code text;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if match_board_size not between 3 and 10 then raise exception 'invalid board size'; end if;
  if match_win_length not between 3 and 5 then raise exception 'invalid win length'; end if;
  if match_opponent_id is not null and match_opponent_id = auth.uid() then
    raise exception 'cannot play against yourself';
  end if;

  generated_code := coalesce(upper(match_invite_code), upper(substr(md5(random()::text), 1, 8)));
  while exists (select 1 from public.matches where invite_code = generated_code) loop
    generated_code := upper(substr(md5(random()::text), 1, 8));
  end loop;

  for i in 1..match_board_size loop
    empty_board := empty_board || jsonb_build_array(
      (select jsonb_agg(''::text) from generate_series(1, match_board_size))
    );
  end loop;

  insert into public.matches (invite_code, player_x, player_o, board_size, win_length, board, current_turn, status)
  values (
    generated_code, auth.uid(), match_opponent_id, match_board_size, match_win_length, empty_board,
    'X', case when match_opponent_id is null then 'waiting' else 'active' end
  ) returning * into new_match;
  return new_match;
end;
$$;

create or replace function public.board_has_winner(
  board_state jsonb,
  board_size integer,
  target_length integer,
  target_symbol text
)
returns boolean
language plpgsql
immutable
as $$
declare
  row_index integer;
  col_index integer;
  step integer;
  row_step integer;
  col_step integer;
  direction integer[];
  end_row integer;
  end_col integer;
  matches boolean;
begin
  for row_index in 0..board_size - 1 loop
    for col_index in 0..board_size - 1 loop
      foreach direction slice 1 in array array[array[0, 1], array[1, 0], array[1, 1], array[1, -1]] loop
        row_step := direction[1];
        col_step := direction[2];
        end_row := row_index + row_step * (target_length - 1);
        end_col := col_index + col_step * (target_length - 1);
        if end_row < 0 or end_row >= board_size or end_col < 0 or end_col >= board_size then
          continue;
        end if;
        matches := true;
        for step in 0..target_length - 1 loop
          if board_state->(row_index + row_step * step)->>(col_index + col_step * step) <> target_symbol then
            matches := false;
            exit;
          end if;
        end loop;
        if matches then return true; end if;
      end loop;
    end loop;
  end loop;
  return false;
end;
$$;

create or replace function public.submit_move(
  target_match_id uuid,
  move_row integer,
  move_col integer
)
returns public.matches
language plpgsql
security definer set search_path = public
as $$
declare
  current_match public.matches;
  next_board jsonb;
  player_symbol text;
  winner_id uuid;
  has_empty boolean := false;
  scan_row integer;
  scan_col integer;
begin
  select * into current_match from public.matches
  where id = target_match_id for update;
  if not found then raise exception 'match not found'; end if;
  if auth.uid() is null or (auth.uid() <> current_match.player_x and auth.uid() <> current_match.player_o)
    then raise exception 'not a participant'; end if;
  if current_match.status <> 'active' then raise exception 'match is not active'; end if;
  if (current_match.current_turn = 'X' and auth.uid() <> current_match.player_x)
    or (current_match.current_turn = 'O' and auth.uid() <> current_match.player_o)
    then raise exception 'not your turn'; end if;
  if move_row < 0 or move_row >= current_match.board_size or move_col < 0 or move_col >= current_match.board_size
    then raise exception 'move out of bounds'; end if;
  if current_match.board->move_row->>move_col <> '' then raise exception 'cell is occupied'; end if;

  player_symbol := current_match.current_turn;
  next_board := jsonb_set(current_match.board, array[move_row::text, move_col::text], to_jsonb(player_symbol));
  winner_id := null;

  if public.board_has_winner(
    next_board,
    current_match.board_size,
    current_match.win_length,
    player_symbol
  ) then
    winner_id := case
      when player_symbol = 'X' then current_match.player_x
      else current_match.player_o
    end;
  end if;

  for scan_row in 0..current_match.board_size - 1 loop
    for scan_col in 0..current_match.board_size - 1 loop
      if next_board->scan_row->>scan_col = '' then has_empty := true; end if;
    end loop;
  end loop;

  update public.matches set
    board = next_board,
    current_turn = case when player_symbol = 'X' then 'O' else 'X' end,
    move_number = move_number + 1,
    status = case when winner_id is not null or not has_empty then 'finished' else status end,
    winner = winner_id,
    finished_at = case when winner_id is not null or not has_empty then now() else finished_at end,
    updated_at = now()
  where id = target_match_id returning * into current_match;
  return current_match;
end;
$$;

create or replace function public.join_match(target_match_code text)
returns public.matches
language plpgsql
security definer set search_path = public
as $$
declare
  joined_match public.matches;
  normalized_code text := upper(trim(target_match_code));
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if normalized_code = '' then raise exception 'match code required'; end if;

  update public.matches
  set player_o = auth.uid(), status = 'active', updated_at = now()
  where (
      invite_code = normalized_code
      or id::text = normalized_code
    )
    and status = 'waiting'
    and player_x <> auth.uid()
    and player_o is null
  returning * into joined_match;

  if joined_match.id is null then raise exception 'match is unavailable'; end if;
  return joined_match;
end;
$$;

revoke all on function public.create_match(integer, integer, uuid, text) from public;
grant execute on function public.create_match(integer, integer, uuid, text) to authenticated;
revoke all on function public.submit_move(uuid, integer, integer) from public;
grant execute on function public.submit_move(uuid, integer, integer) to authenticated;
revoke all on function public.join_match(text) from public;
grant execute on function public.join_match(text) to authenticated;
revoke all on function public.board_has_winner(jsonb, integer, integer, text) from public;
grant execute on function public.board_has_winner(jsonb, integer, integer, text) to authenticated;

create or replace function public.cancel_match(target_match_code text)
returns public.matches
language plpgsql
security definer set search_path = public
as $$
declare
  cancelled_match public.matches;
  normalized_code text := upper(trim(target_match_code));
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.matches
  set status = 'abandoned', updated_at = now(), finished_at = coalesce(finished_at, now())
  where (
      invite_code = normalized_code
      or id::text = normalized_code
    )
    and (player_x = auth.uid() or player_o = auth.uid())
    and status in ('waiting', 'active')
  returning * into cancelled_match;

  if cancelled_match.id is null then raise exception 'match is unavailable'; end if;
  return cancelled_match;
end;
$$;
revoke all on function public.cancel_match(text) from public;
grant execute on function public.cancel_match(text) to authenticated;

alter table public.matches replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.matches;
exception when duplicate_object then null;
end $$;
