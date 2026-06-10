-- Permitir que Seniores insiram notificações para si próprios
DROP POLICY IF EXISTS "notifications_senior_insert" ON public.notifications;
CREATE POLICY "notifications_senior_insert"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (
  id_senior = private.get_my_user_id()
);

-- Permitir que CUIDADORES insiram notificações para os seus IDOSOS associados
DROP POLICY IF EXISTS "notifications_caretaker_insert" ON public.notifications;
CREATE POLICY "notifications_caretaker_insert"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.senior_caretaker sc
    WHERE sc.id_caretaker = private.get_my_user_id()
      AND sc.id_senior = public.notifications.id_senior
  )
);
