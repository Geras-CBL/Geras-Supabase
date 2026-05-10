-- Permitir que CUIDADORES vejam os dados básicos dos seus IDOSOS associados
DROP POLICY IF EXISTS "users_caretaker_select_seniors" ON public.users;
CREATE POLICY "users_caretaker_select_seniors"
ON public.users FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.senior_caretaker sc
    WHERE sc.id_caretaker = private.get_my_user_id()
      AND sc.id_senior = public.users.id
  )
);

-- Permitir que CUIDADORES vejam as notificações dos seus IDOSOS associados
DROP POLICY IF EXISTS "notifications_caretaker_select_seniors" ON public.notifications;
CREATE POLICY "notifications_caretaker_select_seniors"
ON public.notifications FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.senior_caretaker sc
    WHERE sc.id_caretaker = private.get_my_user_id()
      AND sc.id_senior = public.notifications.id_senior
  )
);
