-- CoachIQ production SaaS migration
-- Run once after supabase/schema.sql in the Supabase SQL Editor.
-- It adds academy tenancy, player onboarding, subscriptions, join codes and RLS isolation.

DO $$ BEGIN
  CREATE TYPE public.organization_member_role AS ENUM ('owner', 'coach', 'player');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.subscription_status AS ENUM ('trialing', 'active', 'past_due', 'canceled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organization_members (
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.organization_member_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, user_id)
);

ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS join_code text;
ALTER TABLE public.training_sessions ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS teams_join_code_unique ON public.teams(join_code) WHERE join_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS organization_members_user_idx ON public.organization_members(user_id);
CREATE INDEX IF NOT EXISTS teams_organization_idx ON public.teams(organization_id);
CREATE INDEX IF NOT EXISTS sessions_organization_idx ON public.training_sessions(organization_id, scheduled_for DESC);

CREATE TABLE IF NOT EXISTS public.team_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  email text NOT NULL,
  invited_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, email)
);
ALTER TABLE public.team_invitations ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;
ALTER TABLE public.team_invitations ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending';
ALTER TABLE public.team_invitations ADD COLUMN IF NOT EXISTS expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days');
CREATE INDEX IF NOT EXISTS team_invitations_email_idx ON public.team_invitations(lower(email), status);

CREATE TABLE IF NOT EXISTS public.subscriptions (
  organization_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
  plan text NOT NULL DEFAULT 'free',
  status public.subscription_status NOT NULL DEFAULT 'trialing',
  trial_ends_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  current_period_end timestamptz,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Backfill an academy for existing coaches and attach their old data.
DO $$
DECLARE
  p record;
  org_id uuid;
  slug_value text;
  n integer;
BEGIN
  FOR p IN SELECT id, coalesce(nullif(trim(full_name), ''), 'أكاديمية CoachIQ') AS name
           FROM public.profiles WHERE role = 'coach'
  LOOP
    SELECT om.organization_id INTO org_id
    FROM public.organization_members om
    WHERE om.user_id = p.id AND om.role = 'owner'
    LIMIT 1;

    IF org_id IS NULL THEN
      slug_value := 'academy-' || replace(p.id::text, '-', '');
      n := 1;
      WHILE EXISTS (SELECT 1 FROM public.organizations WHERE slug = slug_value) LOOP
        slug_value := 'academy-' || replace(p.id::text, '-', '') || '-' || n;
        n := n + 1;
      END LOOP;
      INSERT INTO public.organizations(name, slug, created_by)
      VALUES (p.name || ' Academy', slug_value, p.id)
      RETURNING id INTO org_id;
      INSERT INTO public.organization_members(organization_id, user_id, role)
      VALUES (org_id, p.id, 'owner') ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.subscriptions(organization_id) VALUES (org_id) ON CONFLICT DO NOTHING;
    UPDATE public.teams SET organization_id = org_id WHERE coach_id = p.id AND organization_id IS NULL;
    UPDATE public.training_sessions SET organization_id = org_id WHERE coach_id = p.id AND organization_id IS NULL;

    IF NOT EXISTS (SELECT 1 FROM public.teams WHERE coach_id = p.id) THEN
      INSERT INTO public.teams(organization_id, coach_id, name, age_group, level, join_code)
      VALUES (org_id, p.id, 'الفريق الأول', 'U13', 'متوسط', upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
    END IF;
  END LOOP;
END $$;

UPDATE public.teams
SET join_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
WHERE join_code IS NULL;

-- Existing team players become organization members.
INSERT INTO public.organization_members(organization_id, user_id, role)
SELECT DISTINCT t.organization_id, tm.player_id, 'player'::public.organization_member_role
FROM public.team_members tm
JOIN public.teams t ON t.id = tm.team_id
WHERE t.organization_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- RLS-safe helpers. They are SECURITY DEFINER so policies do not recurse through each other.
CREATE OR REPLACE FUNCTION public.is_org_member(target_org uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.organization_members om WHERE om.organization_id = target_org AND om.user_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.is_org_coach(target_org uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.organization_members om WHERE om.organization_id = target_org AND om.user_id = auth.uid() AND om.role IN ('owner','coach'));
$$;

CREATE OR REPLACE FUNCTION public.is_team_coach(target_team uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.teams t WHERE t.id = target_team AND t.coach_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.is_team_player(target_team uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = target_team AND tm.player_id = auth.uid());
$$;

CREATE OR REPLACE FUNCTION public.my_organization()
RETURNS TABLE(id uuid, name text, slug text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT o.id, o.name, o.slug
  FROM public.organizations o
  JOIN public.organization_members om ON om.organization_id = o.id
  WHERE om.user_id = auth.uid()
  ORDER BY CASE WHEN om.role = 'owner' THEN 0 ELSE 1 END, o.created_at
  LIMIT 1;
$$;

-- New accounts: coaches receive their own tenant; players automatically claim pending email invitations.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  new_role public.user_role;
  org_id uuid;
  invite record;
  slug_value text;
  n integer := 1;
BEGIN
  new_role := CASE
    WHEN new.raw_user_meta_data ->> 'role' = 'coach' THEN 'coach'::public.user_role
    ELSE 'player'::public.user_role
  END;

  INSERT INTO public.profiles(id, full_name, role)
  VALUES (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new_role)
  ON CONFLICT (id) DO UPDATE SET full_name = excluded.full_name, role = excluded.role;

  IF new_role = 'coach' THEN
    slug_value := 'academy-' || replace(new.id::text, '-', '');
    WHILE EXISTS (SELECT 1 FROM public.organizations WHERE slug = slug_value) LOOP
      slug_value := 'academy-' || replace(new.id::text, '-', '') || '-' || n;
      n := n + 1;
    END LOOP;

    INSERT INTO public.organizations(name, slug, created_by)
    VALUES (coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'أكاديمية CoachIQ') || ' Academy', slug_value, new.id)
    RETURNING id INTO org_id;

    INSERT INTO public.organization_members(organization_id, user_id, role) VALUES (org_id, new.id, 'owner');
    INSERT INTO public.subscriptions(organization_id) VALUES (org_id);
    INSERT INTO public.teams(organization_id, coach_id, name, age_group, level, join_code)
    VALUES (org_id, new.id, 'الفريق الأول', 'U13', 'متوسط', upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
  ELSE
    FOR invite IN
      SELECT id, organization_id, team_id
      FROM public.team_invitations
      WHERE lower(email) = lower(new.email)
        AND status = 'pending'
        AND expires_at > now()
    LOOP
      INSERT INTO public.organization_members(organization_id, user_id, role)
      VALUES (invite.organization_id, new.id, 'player') ON CONFLICT DO NOTHING;
      INSERT INTO public.team_members(team_id, player_id)
      VALUES (invite.team_id, new.id) ON CONFLICT DO NOTHING;
      UPDATE public.team_invitations SET status = 'accepted' WHERE id = invite.id;
    END LOOP;
  END IF;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

CREATE OR REPLACE FUNCTION public.join_team_by_code(p_code text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  target_team uuid;
  target_org uuid;
  caller_role public.user_role;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role <> 'player' THEN RAISE EXCEPTION 'only players can join a team'; END IF;

  SELECT id, organization_id INTO target_team, target_org
  FROM public.teams
  WHERE upper(join_code) = upper(trim(p_code))
  LIMIT 1;
  IF target_team IS NULL THEN RAISE EXCEPTION 'team code not found'; END IF;

  INSERT INTO public.organization_members(organization_id, user_id, role)
  VALUES (target_org, auth.uid(), 'player') ON CONFLICT DO NOTHING;
  INSERT INTO public.team_members(team_id, player_id)
  VALUES (target_team, auth.uid()) ON CONFLICT DO NOTHING;
  RETURN target_team;
END;
$$;

-- Replace legacy tenant policies with strict, non-overlapping policies.
DROP POLICY IF EXISTS coach_owns_teams ON public.teams;
DROP POLICY IF EXISTS coach_owns_sessions ON public.training_sessions;
DROP POLICY IF EXISTS coach_manages_session_exercises ON public.session_exercises;
DROP POLICY IF EXISTS team_members_visible_to_team_users ON public.team_members;
DROP POLICY IF EXISTS coach_manages_team_members ON public.team_members;
DROP POLICY IF EXISTS player_owns_progress ON public.player_progress;
DROP POLICY IF EXISTS player_owns_challenges ON public.player_challenges;
DROP POLICY IF EXISTS organizations_member_read ON public.organizations;
DROP POLICY IF EXISTS organization_members_self_read ON public.organization_members;
DROP POLICY IF EXISTS teams_org_access ON public.teams;
DROP POLICY IF EXISTS teams_player_read ON public.teams;
DROP POLICY IF EXISTS sessions_org_access ON public.training_sessions;
DROP POLICY IF EXISTS sessions_player_read ON public.training_sessions;
DROP POLICY IF EXISTS training_sessions_player_read ON public.training_sessions;
DROP POLICY IF EXISTS session_exercises_org_access ON public.session_exercises;
DROP POLICY IF EXISTS session_exercises_player_read ON public.session_exercises;
DROP POLICY IF EXISTS team_members_org_access ON public.team_members;
DROP POLICY IF EXISTS team_members_org_manage ON public.team_members;
DROP POLICY IF EXISTS team_members_org_delete ON public.team_members;
DROP POLICY IF EXISTS invitations_org_access ON public.team_invitations;
DROP POLICY IF EXISTS progress_player_or_coach_read ON public.player_progress;
DROP POLICY IF EXISTS progress_player_write ON public.player_progress;
DROP POLICY IF EXISTS challenge_progress_self ON public.player_challenges;
DROP POLICY IF EXISTS profiles_coach_team_read ON public.profiles;
DROP POLICY IF EXISTS subscriptions_member_read ON public.subscriptions;

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY organizations_member_read ON public.organizations FOR SELECT TO authenticated
USING (public.is_org_member(id));

CREATE POLICY organization_members_self_read ON public.organization_members FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_org_coach(organization_id));

CREATE POLICY subscriptions_member_read ON public.subscriptions FOR SELECT TO authenticated
USING (public.is_org_member(organization_id));

CREATE POLICY teams_coach_manage ON public.teams FOR ALL TO authenticated
USING (public.is_org_coach(organization_id) AND coach_id = auth.uid())
WITH CHECK (public.is_org_coach(organization_id) AND coach_id = auth.uid());

CREATE POLICY teams_player_read ON public.teams FOR SELECT TO authenticated
USING (public.is_team_player(id));

CREATE POLICY team_members_read ON public.team_members FOR SELECT TO authenticated
USING (player_id = auth.uid() OR public.is_team_coach(team_id));

CREATE POLICY team_members_coach_manage ON public.team_members FOR DELETE TO authenticated
USING (public.is_team_coach(team_id));

CREATE POLICY team_members_coach_insert ON public.team_members FOR INSERT TO authenticated
WITH CHECK (public.is_team_coach(team_id) AND EXISTS (
  SELECT 1 FROM public.organization_members om
  JOIN public.teams t ON t.organization_id = om.organization_id
  WHERE t.id = team_id AND om.user_id = player_id AND om.role = 'player'
));

CREATE POLICY training_sessions_coach_all ON public.training_sessions FOR ALL TO authenticated
USING (coach_id = auth.uid() AND public.is_org_coach(organization_id))
WITH CHECK (
  coach_id = auth.uid()
  AND public.is_org_coach(organization_id)
  AND (team_id IS NULL OR EXISTS (SELECT 1 FROM public.teams t WHERE t.id = team_id AND t.organization_id = organization_id AND t.coach_id = auth.uid()))
);

CREATE POLICY training_sessions_player_read ON public.training_sessions FOR SELECT TO authenticated
USING (team_id IS NOT NULL AND public.is_team_player(team_id));

CREATE POLICY session_exercises_coach_all ON public.session_exercises FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.training_sessions s WHERE s.id = session_id AND s.coach_id = auth.uid()))
WITH CHECK (EXISTS (SELECT 1 FROM public.training_sessions s WHERE s.id = session_id AND s.coach_id = auth.uid()));

CREATE POLICY session_exercises_player_read ON public.session_exercises FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.training_sessions s
  WHERE s.id = session_id AND s.team_id IS NOT NULL AND public.is_team_player(s.team_id)
));

CREATE POLICY profiles_self_read ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY profiles_self_update ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY profiles_coach_team_read ON public.profiles FOR SELECT TO authenticated
USING (id = auth.uid() OR EXISTS (
  SELECT 1 FROM public.team_members tm
  WHERE tm.player_id = profiles.id AND public.is_team_coach(tm.team_id)
));

CREATE POLICY progress_player_self ON public.player_progress FOR ALL TO authenticated
USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());
CREATE POLICY progress_coach_read ON public.player_progress FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.team_members tm WHERE tm.player_id = player_progress.player_id AND public.is_team_coach(tm.team_id)
));

CREATE POLICY challenge_progress_self ON public.player_challenges FOR ALL TO authenticated
USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());

CREATE POLICY invitations_coach_manage ON public.team_invitations FOR ALL TO authenticated
USING (public.is_org_coach(organization_id) AND invited_by = auth.uid())
WITH CHECK (public.is_org_coach(organization_id) AND invited_by = auth.uid());

CREATE OR REPLACE FUNCTION public.set_session_org()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF new.team_id IS NOT NULL THEN
    SELECT organization_id INTO new.organization_id FROM public.teams WHERE id = new.team_id;
  END IF;
  IF new.organization_id IS NULL THEN
    SELECT om.organization_id INTO new.organization_id
    FROM public.organization_members om
    WHERE om.user_id = new.coach_id AND om.role IN ('owner','coach')
    ORDER BY om.created_at LIMIT 1;
  END IF;
  RETURN new;
END;
$$;
DROP TRIGGER IF EXISTS training_sessions_set_org ON public.training_sessions;
CREATE TRIGGER training_sessions_set_org BEFORE INSERT OR UPDATE ON public.training_sessions
FOR EACH ROW EXECUTE PROCEDURE public.set_session_org();

CREATE OR REPLACE FUNCTION public.set_invitation_org()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  SELECT organization_id INTO new.organization_id FROM public.teams WHERE id = new.team_id;
  RETURN new;
END;
$$;
DROP TRIGGER IF EXISTS team_invitations_set_org ON public.team_invitations;
CREATE TRIGGER team_invitations_set_org BEFORE INSERT OR UPDATE ON public.team_invitations
FOR EACH ROW EXECUTE PROCEDURE public.set_invitation_org();

REVOKE ALL ON FUNCTION public.my_organization() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_organization() TO authenticated;
REVOKE ALL ON FUNCTION public.join_team_by_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_team_by_code(text) TO authenticated;

COMMENT ON TABLE public.organizations IS 'Tenant boundary for CoachIQ academies';
COMMENT ON TABLE public.subscriptions IS 'SaaS billing state; never store payment secrets here';
