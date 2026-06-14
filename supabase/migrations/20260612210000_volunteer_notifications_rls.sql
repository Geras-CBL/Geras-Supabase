-- ============================================================
-- Políticas RLS para voluntários em notifications:
-- 1. SELECT: ver as suas notificações (id_volunteer) + broadcast (sem id_volunteer e sem id_caretaker)
-- 2. UPDATE: marcar como dismissed_at (apenas as suas ou broadcast)
-- ============================================================

-- SELECT: voluntário vê as suas notificações e as broadcast
DROP POLICY IF EXISTS "notifications_volunteer_select" ON public.notifications;
CREATE POLICY "notifications_volunteer_select"
ON public.notifications FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'VOLUNTEER'
      AND (
        -- Notificação dirigida especificamente a este voluntário
        public.notifications.id_volunteer = u.id
        OR
        -- Notificação broadcast (sem destinatário específico de voluntário ou cuidador)
        (public.notifications.id_volunteer IS NULL AND public.notifications.id_caretaker IS NULL)
      )
  )
);

-- UPDATE (dismiss): voluntário pode fechar as suas notificações ou broadcasts
DROP POLICY IF EXISTS "notifications_volunteer_dismiss" ON public.notifications;
CREATE POLICY "notifications_volunteer_dismiss"
ON public.notifications FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'VOLUNTEER'
      AND (
        public.notifications.id_volunteer = u.id
        OR
        (public.notifications.id_volunteer IS NULL AND public.notifications.id_caretaker IS NULL)
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = private.get_my_user_id()
      AND u.role = 'VOLUNTEER'
      AND (
        public.notifications.id_volunteer = u.id
        OR
        (public.notifications.id_volunteer IS NULL AND public.notifications.id_caretaker IS NULL)
      )
  )
);

-- INSERT: o trigger SECURITY DEFINER já insere, mas garantir que o voluntário
-- também pode inserir notificações para si próprio (caso necessário)
DROP POLICY IF EXISTS "notifications_volunteer_insert" ON public.notifications;
CREATE POLICY "notifications_volunteer_insert"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (
  id_volunteer = private.get_my_user_id()
);
