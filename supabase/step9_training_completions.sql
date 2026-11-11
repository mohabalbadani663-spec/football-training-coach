-- CoachIQ Step 9: training completion tracking.

create table if not exists public.training_completions (
  session_id uuid not null references public.training_sessions(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  exercises_completed integer not null default 0 check (exercises_completed >= 0),
  completed_at timestamptz not null default now(),
  primary key (session_id, player_id)
);

create index if not exists training_completions_player_idx on public.training_completions(player_id, completed_at desc);
alter table public.training_completions enable row level security;

drop policy if exists training_completions_self_manage on public.training_completions;
drop policy if exists training_completions_coach_read on public.training_completions;

create policy training_completions_self_manage on public.training_completions
for all to authenticated
using (player_id = auth.uid())
with check (player_id = auth.uid());

create policy training_completions_coach_read on public.training_completions
for select to authenticated
using (exists (select 1 from public.training_sessions s where s.id = session_id and s.coach_id = auth.uid()));
