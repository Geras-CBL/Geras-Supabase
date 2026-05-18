-- Drop the problematic policy that causes infinite recursion
DROP POLICY IF EXISTS "users_volunteer_select_senior" ON public.users;
DROP POLICY IF EXISTS "users_volunteer_select_senior_temp" ON public.users;

-- Create a SECURITY DEFINER function to check if a user_id is a senior
-- on any request visible to the current volunteer. This avoids the
-- infinite recursion because SECURITY DEFINER bypasses RLS.
CREATE OR REPLACE FUNCTION private.is_senior_on_visible_request(target_user_id int)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.requests r
    WHERE r.id_senior = target_user_id
      AND (r.state = 'PENDING' OR r.id_volunteer = private.get_my_user_id())
  );
$$;

-- Now create the policy using the helper function (no recursion)
CREATE POLICY "users_volunteer_select_senior"
ON public.users FOR SELECT TO authenticated
USING (
  private.is_senior_on_visible_request(public.users.id)
);
