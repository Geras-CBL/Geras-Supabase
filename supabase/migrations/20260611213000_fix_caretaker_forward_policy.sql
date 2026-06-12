-- Fix Caretaker Update Policies

-- 1) Caretaker deve conseguir reencaminhar (fazer update de is_public) os seus próprios pedidos PENDING
DROP POLICY IF EXISTS "requests_caretaker_forward_to_volunteer" ON public.requests;
DROP POLICY IF EXISTS "requests_caretaker_forward" ON public.requests;

CREATE POLICY "requests_caretaker_forward"
ON public.requests FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'CARETAKER'
      AND public.requests.id_caretaker = u.id
      AND public.requests.state = 'PENDING'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'CARETAKER'
      AND public.requests.id_caretaker = u.id
  )
);

-- 2) Caretaker deve conseguir Aceitar pedidos PENDING (que o sénior atribuiu a si próprio, ou que estão disponíveis)
DROP POLICY IF EXISTS "requests_caretaker_accept" ON public.requests;

CREATE POLICY "requests_caretaker_accept"
ON public.requests FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'CARETAKER'
      AND public.requests.state = 'PENDING'
      AND (public.requests.id_caretaker IS NULL OR public.requests.id_caretaker = u.id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'CARETAKER'
      AND public.requests.id_caretaker = u.id
      AND public.requests.state = 'ACCEPTED'
  )
);
