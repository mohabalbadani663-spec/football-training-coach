-- CoachIQ Step 8: weekly training plans.

create table if not exists public.weekly_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  coach_id uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,
  day_index integer not null check (day_index between 0 and 6),
  title text not null,
  objective text not null default '',
  session_id uuid references public.training_sessions(id) on delete set null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(team_id, week_start, day_index)
);

create index if not exists weekly_plans_team_week_idx on public.weekly_plans(team_id, week_start, day_index);
alter table public.weekly_plans enable row level security;

drop policy if exists weekly_plans_coach_manage on public.weekly_plans;
drop policy if exists weekly_plans_player_read on public.weekly_plans;

create policy weekly_plans_coach_manage on public.weekly_plans
for all to authenticated
using (coach_id = auth.uid() and public.is_org_coach(organization_id))
with check (
  coach_id = auth.uid()
  and public.is_org_coach(organization_id)
  and exists (select 1 from public.teams t where t.id = team_id and t.organization_id = organization_id and t.coach_id = auth.uid())
);

create policy weekly_plans_player_read on public.weekly_plans
for select to authenticated
using (public.is_team_player(team_id));

create or replace function public.set_weekly_plan_org()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select t.organization_id into new.organization_id from public.teams t where t.id = new.team_id;
  if new.organization_id is null then raise exception 'الفريق غير مرتبط بأكاديمية'; end if;
  return new;
end;
$$;

drop trigger if exists weekly_plans_set_org on public.weekly_plans;
create trigger weekly_plans_set_org before insert or update of team_id on public.weekly_plans for each row execute procedure public.set_weekly_plan_org();
