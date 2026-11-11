-- Football Training Platform - MVP Supabase schema
-- Run this file in the Supabase SQL Editor after creating a project.

create extension if not exists "pgcrypto";

create type public.user_role as enum ('coach', 'player');
create type public.exercise_category as enum ('technical', 'physical', 'tactical', 'cognitive');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.user_role not null default 'player',
  position text,
  age integer,
  level text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  age_group text,
  level text,
  created_at timestamptz not null default now()
);

create table public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (team_id, player_id)
);

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_en text not null default '',
  objective text not null default '',
  category public.exercise_category not null default 'technical',
  duration_minutes integer not null default 10 check (duration_minutes > 0),
  age text not null default '',
  players text not null default '',
  difficulty text not null default '',
  space text not null default '',
  equipment text not null default '',
  description text not null default '',
  instructions jsonb not null default '[]'::jsonb,
  coaching_points jsonb not null default '[]'::jsonb,
  progression text not null default '',
  regression text not null default '',
  diagram_url text,
  video_url text,
  created_at timestamptz not null default now()
);

create table public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  title text not null,
  objective text not null default '',
  duration_minutes integer not null default 60 check (duration_minutes > 0),
  scheduled_for timestamptz not null default now(),
  notes text not null default '',
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.session_exercises (
  session_id uuid not null references public.training_sessions(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  sort_order integer not null default 0,
  duration_minutes integer not null default 10 check (duration_minutes > 0),
  primary key (session_id, exercise_id)
);

create table public.player_progress (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  skill_key text not null,
  skill_label text not null,
  progress integer not null default 0 check (progress between 0 and 100),
  updated_at timestamptz not null default now(),
  unique (player_id, skill_key)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  target integer not null default 1 check (target > 0),
  xp_reward integer not null default 0 check (xp_reward >= 0),
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.player_challenges (
  player_id uuid not null references public.profiles(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  progress integer not null default 0 check (progress >= 0),
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (player_id, challenge_id)
);

create index teams_coach_id_idx on public.teams(coach_id);
create index team_members_player_id_idx on public.team_members(player_id);
create index sessions_coach_date_idx on public.training_sessions(coach_id, scheduled_for desc);
create index session_exercises_order_idx on public.session_exercises(session_id, sort_order);
create index player_progress_player_id_idx on public.player_progress(player_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    case
      when (new.raw_user_meta_data ->> 'role') = 'coach' then 'coach'::public.user_role
      else 'player'::public.user_role
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.exercises enable row level security;
alter table public.training_sessions enable row level security;
alter table public.session_exercises enable row level security;
alter table public.player_progress enable row level security;
alter table public.challenges enable row level security;
alter table public.player_challenges enable row level security;

create policy "profiles_self_read" on public.profiles for select using (id = auth.uid());
create policy "profiles_self_update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy "coach_owns_teams" on public.teams for all using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy "team_members_visible_to_team_users" on public.team_members for select using (
  player_id = auth.uid() or exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid())
);
create policy "coach_manages_team_members" on public.team_members for all using (
  exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid())
) with check (
  exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid())
);

create policy "authenticated_read_exercises" on public.exercises for select to authenticated using (true);
create policy "authenticated_read_challenges" on public.challenges for select to authenticated using (true);

create policy "coach_owns_sessions" on public.training_sessions for all using (coach_id = auth.uid()) with check (coach_id = auth.uid());
create policy "coach_manages_session_exercises" on public.session_exercises for all using (
  exists (select 1 from public.training_sessions s where s.id = session_id and s.coach_id = auth.uid())
) with check (
  exists (select 1 from public.training_sessions s where s.id = session_id and s.coach_id = auth.uid())
);

create policy "player_owns_progress" on public.player_progress for all using (player_id = auth.uid()) with check (player_id = auth.uid());
create policy "player_owns_challenges" on public.player_challenges for all using (player_id = auth.uid()) with check (player_id = auth.uid());
-- CoachIQ SaaS tenancy migration.
-- Run after schema.sql in the Supabase SQL Editor.
-- This migration keeps the existing coach_id/team_id model while adding
-- organization-level isolation and invitation-based player onboarding.

do $$ begin
  create type public.organization_member_role as enum ('owner', 'coach', 'player');
exception when duplicate_object then null; end $$;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.organization_member_role not null,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

alter table public.teams add column if not exists organization_id uuid references public.organizations(id) on delete cascade;
alter table public.training_sessions add column if not exists organization_id uuid references public.organizations(id) on delete cascade;

alter table public.teams add column if not exists invite_code text;
create unique index if not exists teams_invite_code_unique on public.teams(invite_code) where invite_code is not null;

create table if not exists public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  email text not null,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(),
  unique (team_id, email)
);

create index if not exists organization_members_user_idx on public.organization_members(user_id);
create index if not exists teams_org_idx on public.teams(organization_id);
create index if not exists sessions_org_idx on public.training_sessions(organization_id, scheduled_for desc);
create index if not exists invitations_email_idx on public.team_invitations(lower(email), status);

do $$ begin
  create type public.subscription_status as enum ('trialing', 'active', 'past_due', 'canceled');
exception when duplicate_object then null; end $$;
create table if not exists public.subscriptions (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  plan text not null default 'free',
  status public.subscription_status not null default 'trialing',
  trial_ends_at timestamptz not null default (now() + interval '14 days'),
  current_period_end timestamptz,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Backfill an organization for every existing coach. The generated slug is
-- deterministic enough for a one-time migration and is made unique below.
do $$
declare
  p record;
  org_id uuid;
  base_slug text;
  final_slug text;
  n integer;
begin
  for p in select id, coalesce(nullif(trim(full_name), ''), 'أكاديمية CoachIQ') as name from public.profiles where role = 'coach' loop
    select om.organization_id into org_id
      from public.organization_members om
     where om.user_id = p.id and om.role in ('owner','coach')
     limit 1;

    if org_id is null then
      base_slug := 'academy-' || replace(p.id::text, '-', '');
      final_slug := base_slug;
      n := 1;
      while exists (select 1 from public.organizations where slug = final_slug) loop
        final_slug := base_slug || '-' || n;
        n := n + 1;
      end loop;

      insert into public.organizations(name, slug, created_by)
      values (p.name || ' Academy', final_slug, p.id)
      returning id into org_id;

      insert into public.organization_members(organization_id, user_id, role)
      values (org_id, p.id, 'owner')
      on conflict do nothing;
      insert into public.subscriptions(organization_id) values (org_id) on conflict do nothing;
    end if;

    update public.teams
       set organization_id = org_id
     where coach_id = p.id and organization_id is null;

    update public.training_sessions s
       set organization_id = org_id
     where s.coach_id = p.id and s.organization_id is null;

    if not exists (select 1 from public.teams where coach_id = p.id) then
      insert into public.teams(organization_id, coach_id, name, age_group, level, invite_code)
      values (org_id, p.id, 'الفريق الأول', 'U13', 'متوسط', upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 10)));
    end if;
  end loop;
end $$;

update public.teams
set invite_code = upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 10))
where invite_code is null;

-- Any player already attached to a team becomes a member of that team's org.
insert into public.organization_members(organization_id, user_id, role)
select distinct t.organization_id, tm.player_id, 'player'::public.organization_member_role
from public.team_members tm
join public.teams t on t.id = tm.team_id
where t.organization_id is not null
on conflict do nothing;

create or replace function public.is_org_member(target_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organization_members
    where organization_id = target_org and user_id = auth.uid()
  );
$$;

create or replace function public.is_org_coach(target_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organization_members
    where organization_id = target_org
      and user_id = auth.uid()
      and role in ('owner','coach')
  );
$$;

create or replace function public.my_organization()
returns table(id uuid, name text, slug text)
language sql stable security definer set search_path = public as $$
  select o.id, o.name, o.slug
  from public.organizations o
  join public.organization_members om on om.organization_id = o.id
  where om.user_id = auth.uid()
  order by case when om.role = 'owner' then 0 else 1 end, o.created_at
  limit 1;
$$;

create or replace function public.is_team_player(target_team uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members where team_id = target_team and player_id = auth.uid());
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  new_role public.user_role;
  org_id uuid;
  invite record;
  base_slug text;
  final_slug text;
  n integer := 1;
begin
  new_role := case
    when (new.raw_user_meta_data ->> 'role') = 'coach' then 'coach'::public.user_role
    else 'player'::public.user_role
  end;

  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new_role)
  on conflict (id) do update set
    full_name = excluded.full_name,
    role = excluded.role;

  if new_role = 'coach' then
    base_slug := 'academy-' || replace(new.id::text, '-', '');
    final_slug := base_slug;
    while exists (select 1 from public.organizations where slug = final_slug) loop
      final_slug := base_slug || '-' || n;
      n := n + 1;
    end loop;

    insert into public.organizations(name, slug, created_by)
    values (coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'أكاديمية CoachIQ') || ' Academy', final_slug, new.id)
    returning id into org_id;

    insert into public.organization_members(organization_id, user_id, role)
    values (org_id, new.id, 'owner');
    insert into public.subscriptions(organization_id) values (org_id) on conflict do nothing;

    insert into public.teams(organization_id, coach_id, name, age_group, level, invite_code)
    values (org_id, new.id, 'الفريق الأول', 'U13', 'متوسط', upper(substr(encode(gen_random_bytes(6), 'hex'), 1, 10)));
  end if;

  -- Accept all still-valid invitations for the email used to register.
  if new_role = 'player' then
    for invite in
      select ti.id, ti.organization_id, ti.team_id
      from public.team_invitations ti
      where lower(ti.email) = lower(new.email)
        and ti.status = 'pending'
        and ti.expires_at > now()
    loop
      insert into public.organization_members(organization_id, user_id, role)
      values (invite.organization_id, new.id, 'player')
      on conflict do nothing;

      insert into public.team_members(team_id, player_id)
      values (invite.team_id, new.id)
      on conflict do nothing;

      update public.team_invitations
         set status = 'accepted'
       where id = invite.id;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Replace the old policies with organization-aware policies.
drop policy if exists coach_owns_teams on public.teams;
drop policy if exists coach_owns_sessions on public.training_sessions;
drop policy if exists coach_manages_session_exercises on public.session_exercises;
drop policy if exists team_members_visible_to_team_users on public.team_members;
drop policy if exists coach_manages_team_members on public.team_members;
drop policy if exists player_owns_progress on public.player_progress;
drop policy if exists player_owns_challenges on public.player_challenges;

drop policy if exists organizations_member_read on public.organizations;
drop policy if exists organization_members_self_read on public.organization_members;
drop policy if exists teams_org_access on public.teams;
drop policy if exists sessions_org_access on public.training_sessions;
drop policy if exists session_exercises_org_access on public.session_exercises;
drop policy if exists team_members_org_access on public.team_members;
drop policy if exists invitations_org_access on public.team_invitations;
drop policy if exists progress_player_or_coach_read on public.player_progress;
drop policy if exists progress_player_write on public.player_progress;
drop policy if exists challenge_progress_self on public.player_challenges;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.team_invitations enable row level security;

create policy organizations_member_read on public.organizations
for select to authenticated using (public.is_org_member(id));

create policy organization_members_self_read on public.organization_members
for select to authenticated using (user_id = auth.uid() or public.is_org_coach(organization_id));

create policy subscriptions_member_read on public.subscriptions
for select to authenticated using (public.is_org_member(organization_id));

create policy teams_org_access on public.teams
for all to authenticated
using (public.is_org_coach(organization_id))
with check (public.is_org_coach(organization_id) and coach_id = auth.uid());

create policy teams_player_read on public.teams
for select to authenticated using (public.is_team_player(id));

create policy sessions_org_access on public.training_sessions
for all to authenticated
using (public.is_org_coach(organization_id))
with check (
  public.is_org_coach(organization_id)
  and coach_id = auth.uid()
  and (team_id is null or exists (select 1 from public.teams t where t.id = team_id and t.organization_id = organization_id))
);

create policy sessions_player_read on public.training_sessions
for select to authenticated using (team_id is not null and exists (select 1 from public.team_members tm where tm.team_id = training_sessions.team_id and tm.player_id = auth.uid()));

create policy session_exercises_org_access on public.session_exercises
for all to authenticated
using (exists (
  select 1 from public.training_sessions s
  where s.id = session_id and public.is_org_coach(s.organization_id)
))
with check (exists (
  select 1 from public.training_sessions s
  where s.id = session_id and public.is_org_coach(s.organization_id)
));

create policy session_exercises_player_read on public.session_exercises
for select to authenticated using (exists (
  select 1 from public.training_sessions s
  join public.team_members tm on tm.team_id = s.team_id
  where s.id = session_id and tm.player_id = auth.uid()
));

create policy team_members_org_access on public.team_members
for select to authenticated using (
  player_id = auth.uid()
  or exists (select 1 from public.teams t where t.id = team_id and public.is_org_member(t.organization_id))
);

create policy team_members_org_manage on public.team_members
for insert to authenticated with check (
  exists (select 1 from public.teams t where t.id = team_id and public.is_org_coach(t.organization_id))
  and exists (select 1 from public.organization_members om where om.organization_id = (select t.organization_id from public.teams t where t.id = public.team_members.team_id) and om.user_id = player_id and om.role = 'player')
);

create policy team_members_org_delete on public.team_members
for delete to authenticated using (
  exists (select 1 from public.teams t where t.id = team_id and public.is_org_coach(t.organization_id))
);

create policy invitations_org_access on public.team_invitations
for all to authenticated
using (public.is_org_coach(organization_id) or lower(email) = lower((select email from auth.users where id = auth.uid())))
with check (public.is_org_coach(organization_id) and invited_by = auth.uid());

create policy profiles_coach_team_read on public.profiles
for select to authenticated using (id = auth.uid() or exists (
  select 1 from public.team_members tm
  join public.teams t on t.id = tm.team_id
  where tm.player_id = profiles.id and public.is_org_coach(t.organization_id)
));

create policy progress_player_or_coach_read on public.player_progress
for select to authenticated using (
  player_id = auth.uid()
  or exists (
    select 1 from public.team_members tm
    join public.teams t on t.id = tm.team_id
    where tm.player_id = player_progress.player_id and public.is_org_coach(t.organization_id)
  )
);

create policy progress_player_write on public.player_progress
for all to authenticated using (player_id = auth.uid()) with check (player_id = auth.uid());

create policy challenge_progress_self on public.player_challenges
for all to authenticated using (player_id = auth.uid()) with check (player_id = auth.uid());

-- Ensure all rows written by the app carry the correct organization.
create or replace function public.set_session_org()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.organization_id is null and new.team_id is not null then
    select organization_id into new.organization_id from public.teams where id = new.team_id;
  end if;
  if new.organization_id is null then
    select om.organization_id into new.organization_id
      from public.organization_members om
     where om.user_id = new.coach_id and om.role in ('owner','coach')
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists training_sessions_set_org on public.training_sessions;
create trigger training_sessions_set_org
before insert or update on public.training_sessions
for each row execute procedure public.set_session_org();

-- New accounts should not inherit a role chosen only in the client after signup.
-- The trigger is the authoritative source for the role stored in profiles.

-- Player read access: a player can only read sessions/exercises belonging to teams
-- they actually joined. Coaches keep full access to their organization.
create policy training_sessions_player_read on public.training_sessions
for select to authenticated
using (
  exists (
    select 1 from public.team_members tm
    where tm.team_id = training_sessions.team_id
      and tm.player_id = auth.uid()
  )
);

create policy session_exercises_player_read on public.session_exercises
for select to authenticated
using (
  exists (
    select 1
    from public.training_sessions s
    join public.team_members tm on tm.team_id = s.team_id
    where s.id = session_exercises.session_id
      and tm.player_id = auth.uid()
  )
);

-- Players should not receive the entire academy roster through team_members.
drop policy if exists team_members_org_access on public.team_members;
create policy team_members_org_access on public.team_members
for select to authenticated using (
  player_id = auth.uid()
  or exists (
    select 1 from public.teams t
    where t.id = team_members.team_id and public.is_org_coach(t.organization_id)
  )
);

-- Short, human-shareable team code. It is not a security secret; RLS still
-- controls what a player can do after joining.
alter table public.teams add column if not exists join_code text;
update public.teams
set join_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
where join_code is null;
create unique index if not exists teams_join_code_unique on public.teams(join_code) where join_code is not null;

create or replace function public.my_organization()
returns table(id uuid, name text, slug text)
language sql stable security definer set search_path = public
as $$
  select o.id, o.name, o.slug
  from public.organizations o
  join public.organization_members om on om.organization_id = o.id
  where om.user_id = auth.uid()
  order by om.created_at
  limit 1;
$$;

create or replace function public.join_team_by_code(p_code text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  target_team uuid;
  target_org uuid;
  caller_role public.user_role;
begin
  select role into caller_role from public.profiles where id = auth.uid();
  if caller_role <> 'player' then
    raise exception 'only players can join a team';
  end if;

  select id, organization_id into target_team, target_org
  from public.teams
  where upper(join_code) = upper(trim(p_code))
  limit 1;

  if target_team is null then raise exception 'team code not found'; end if;

  insert into public.organization_members(organization_id, user_id, role)
  values (target_org, auth.uid(), 'player')
  on conflict do nothing;

  insert into public.team_members(team_id, player_id)
  values (target_team, auth.uid())
  on conflict do nothing;

  return target_team;
end;
$$;

revoke all on function public.my_organization() from public;
grant execute on function public.my_organization() to authenticated;
revoke all on function public.join_team_by_code(text) from public;
grant execute on function public.join_team_by_code(text) to authenticated;

grant execute on function public.my_organization() to authenticated;

create or replace function public.set_invitation_org()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.organization_id is null then
    select organization_id into new.organization_id from public.teams where id = new.team_id;
  end if;
  return new;
end;
$$;

drop trigger if exists team_invitations_set_org on public.team_invitations;
create trigger team_invitations_set_org
before insert or update on public.team_invitations
for each row execute procedure public.set_invitation_org();

-- Profile visibility for coaches inside the same academy. Keep player data
-- private across academies.
create policy profiles_org_read on public.profiles
for select to authenticated using (
  id = auth.uid()
  or exists (
    select 1 from public.organization_members om
    where om.user_id = public.profiles.id
      and public.is_org_coach(om.organization_id)
  )
  or exists (
    select 1
    from public.team_members tm
    join public.teams t on t.id = tm.team_id
    where tm.player_id = public.profiles.id
      and public.is_org_coach(t.organization_id)
  )
);

create or replace function public.prevent_profile_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    new.role := old.role;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_prevent_role_change on public.profiles;
create trigger profiles_prevent_role_change
before update on public.profiles
for each row execute procedure public.prevent_profile_role_change();

alter table public.teams
  alter column join_code set default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
