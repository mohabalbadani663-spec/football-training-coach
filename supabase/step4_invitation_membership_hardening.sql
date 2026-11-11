-- CoachIQ Step 4: invitation and membership RLS hardening.
-- Applied to project football-training-platform.

drop policy if exists invitations_coach_manage on public.team_invitations;
drop policy if exists invitations_org_access on public.team_invitations;

create policy team_invitations_read on public.team_invitations
for select to authenticated
using (
  public.is_org_coach(organization_id)
  or lower(email) = lower((select email from auth.users where id = auth.uid()))
);

create policy team_invitations_insert on public.team_invitations
for insert to authenticated
with check (public.is_org_coach(organization_id) and invited_by = auth.uid());

create policy team_invitations_update on public.team_invitations
for update to authenticated
using (public.is_org_coach(organization_id))
with check (public.is_org_coach(organization_id) and invited_by = auth.uid());

create policy team_invitations_delete on public.team_invitations
for delete to authenticated
using (public.is_org_coach(organization_id));

drop policy if exists team_members_org_access on public.team_members;
drop policy if exists team_members_read on public.team_members;

create policy team_members_scoped_read on public.team_members
for select to authenticated
using (
  player_id = auth.uid()
  or exists (
    select 1 from public.teams t
    where t.id = team_id and public.is_org_coach(t.organization_id)
  )
);

comment on policy team_invitations_read on public.team_invitations is
  'Players can only read invitations addressed to their authenticated email; coaches can read their organization invitations.';
comment on policy team_members_scoped_read on public.team_members is
  'Players see only their own membership; organization coaches see their roster.';
