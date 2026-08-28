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
