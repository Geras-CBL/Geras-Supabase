-- Adicionar coluna is_public à tabela requests
ALTER TABLE public.requests
ADD COLUMN is_public BOOLEAN DEFAULT false;

-- Atualizar a política de visualização dos voluntários
DROP POLICY IF EXISTS "requests_volunteer_select_pending_or_own" ON public.requests;

CREATE POLICY "requests_volunteer_select_pending_or_own"
ON public.requests FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'VOLUNTEER'
      AND (
        (public.requests.state = 'PENDING' AND public.requests.is_public = true)
        OR public.requests.id_volunteer = u.id
      )
  )
);
