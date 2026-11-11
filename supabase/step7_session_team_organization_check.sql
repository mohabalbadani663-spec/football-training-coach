-- CoachIQ Step 7: keep edited sessions inside the coach's organization.
-- Applied to project football-training-platform.

drop policy if exists training_sessions_coach_all on public.training_sessions;

create policy training_sessions_coach_all on public.training_sessions
for all to authenticated
using (
  coach_id = auth.uid()
  and public.is_org_coach(organization_id)
)
with check (
  coach_id = auth.uid()
  and public.is_org_coach(organization_id)
  and (
    team_id is null
    or exists (
      select 1
      from public.teams t
      where t.id = public.training_sessions.team_id
        and t.organization_id = public.training_sessions.organization_id
        and t.coach_id = auth.uid()
    )
  )
);
