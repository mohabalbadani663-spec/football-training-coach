-- CoachIQ production security checks + tenant consistency hardening.
-- Run AFTER saas_migration.sql and saas_hardening.sql.
-- This file is idempotent and does not expose secrets.

-- 1) Tenant integrity: a team must belong to the same organization as its coach.
CREATE OR REPLACE FUNCTION public.validate_team_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE coach_org uuid;
BEGIN
  SELECT om.organization_id INTO coach_org
  FROM public.organization_members om
  WHERE om.user_id = NEW.coach_id
    AND om.organization_id = NEW.organization_id
    AND om.role IN ('owner','coach')
  LIMIT 1;
  IF coach_org IS NULL THEN
    RAISE EXCEPTION 'coach is not a member of the team organization';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS teams_validate_tenant ON public.teams;
CREATE TRIGGER teams_validate_tenant
BEFORE INSERT OR UPDATE OF organization_id, coach_id ON public.teams
FOR EACH ROW EXECUTE FUNCTION public.validate_team_tenant();

-- 2) Session tenant must match its team and the authenticated coach's tenant.
CREATE OR REPLACE FUNCTION public.validate_session_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE team_org uuid;
BEGIN
  IF NEW.team_id IS NOT NULL THEN
    SELECT organization_id INTO team_org FROM public.teams WHERE id = NEW.team_id;
    IF team_org IS NULL OR team_org IS DISTINCT FROM NEW.organization_id THEN
      RAISE EXCEPTION 'session team and organization do not match';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.teams
      WHERE id = NEW.team_id AND coach_id = NEW.coach_id
    ) THEN
      RAISE EXCEPTION 'coach does not own the selected team';
    END IF;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.organization_members
    WHERE organization_id = NEW.organization_id
      AND user_id = NEW.coach_id
      AND role IN ('owner','coach')
  ) THEN
    RAISE EXCEPTION 'coach is not a member of the session organization';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS training_sessions_validate_tenant ON public.training_sessions;
CREATE TRIGGER training_sessions_validate_tenant
BEFORE INSERT OR UPDATE OF organization_id, team_id, coach_id ON public.training_sessions
FOR EACH ROW EXECUTE FUNCTION public.validate_session_tenant();

-- 3) Invitations can only target a team in the same organization.
CREATE OR REPLACE FUNCTION public.validate_invitation_tenant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE team_org uuid;
BEGIN
  SELECT organization_id INTO team_org FROM public.teams WHERE id = NEW.team_id;
  IF team_org IS NULL OR team_org IS DISTINCT FROM NEW.organization_id THEN
    RAISE EXCEPTION 'invitation team and organization do not match';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS team_invitations_validate_tenant ON public.team_invitations;
CREATE TRIGGER team_invitations_validate_tenant
BEFORE INSERT OR UPDATE OF organization_id, team_id ON public.team_invitations
FOR EACH ROW EXECUTE FUNCTION public.validate_invitation_tenant();

-- 4) Basic data constraints.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_age_range;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_age_range CHECK (age IS NULL OR age BETWEEN 5 AND 100);
ALTER TABLE public.player_progress DROP CONSTRAINT IF EXISTS player_progress_range;
ALTER TABLE public.player_progress ADD CONSTRAINT player_progress_range CHECK (progress BETWEEN 0 AND 100);

-- 5) Useful production indexes.
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);
CREATE INDEX IF NOT EXISTS team_members_team_idx ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS training_sessions_org_date_idx ON public.training_sessions(organization_id, scheduled_for DESC);
CREATE INDEX IF NOT EXISTS player_progress_updated_idx ON public.player_progress(player_id, updated_at DESC);

-- 6) Security verification output.
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles','organizations','organization_members','subscriptions',
    'teams','team_members','team_invitations','training_sessions',
    'session_exercises','player_progress','player_challenges'
  )
ORDER BY tablename;

SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
