-- CoachIQ security hardening applied on the connected Supabase project.
-- This migration is safe to re-run and keeps only application RPCs callable by signed-in users.

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_org_member(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_org_coach(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_team_coach(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_team_player(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.prevent_client_role_change() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.protect_organization_owner() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_session_org() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_invitation_org() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.validate_team_tenant() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.validate_session_tenant() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.validate_invitation_tenant() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.join_team_by_code(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.my_organization() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_team_by_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_organization() TO authenticated;
