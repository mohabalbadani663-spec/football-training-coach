-- CoachIQ SaaS hardening (run after saas_migration.sql)
-- Safe to run more than once.

-- A signed-in client must never be able to promote itself by changing profiles.role.
CREATE OR REPLACE FUNCTION public.prevent_client_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     AND COALESCE(current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'profile role cannot be changed by the client';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_protect_role ON public.profiles;
CREATE TRIGGER profiles_protect_role
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.prevent_client_role_change();

-- Keep organization ownership immutable from the client side.
CREATE OR REPLACE FUNCTION public.protect_organization_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.role = 'owner' THEN RAISE EXCEPTION 'organization owner membership cannot be deleted'; END IF;
    RETURN OLD;
  END IF;
  IF OLD.role = 'owner' AND NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'organization owner role cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS organization_members_protect_owner ON public.organization_members;
CREATE TRIGGER organization_members_protect_owner
BEFORE UPDATE OR DELETE ON public.organization_members
FOR EACH ROW EXECUTE FUNCTION public.protect_organization_owner();

-- Faster tenant-scoped lookups and safer duplicate protection.
CREATE INDEX IF NOT EXISTS organization_members_org_role_idx
  ON public.organization_members(organization_id, role);
CREATE INDEX IF NOT EXISTS team_members_team_player_idx
  ON public.team_members(team_id, player_id);
CREATE INDEX IF NOT EXISTS sessions_team_date_idx
  ON public.training_sessions(team_id, scheduled_for DESC);
CREATE INDEX IF NOT EXISTS invitations_team_status_idx
  ON public.team_invitations(team_id, status);

-- Prevent malformed tenant rows from being written by privileged backend jobs.
ALTER TABLE public.teams
  ADD CONSTRAINT teams_org_coach_not_null CHECK (organization_id IS NOT NULL) NOT VALID;
ALTER TABLE public.training_sessions
  ADD CONSTRAINT sessions_org_not_null CHECK (organization_id IS NOT NULL) NOT VALID;

-- Do not expose billing provider identifiers through broad client access.
REVOKE ALL ON public.subscriptions FROM anon;
REVOKE ALL ON public.subscriptions FROM authenticated;
GRANT SELECT (organization_id, plan, status, trial_ends_at, current_period_end, created_at, updated_at)
  ON public.subscriptions TO authenticated;

COMMENT ON FUNCTION public.prevent_client_role_change() IS 'Prevents client-side privilege escalation through profiles.role';
