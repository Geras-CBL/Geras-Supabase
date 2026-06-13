-- Permitir que CUIDADORES atualizem as notificações dos seus IDOSOS associados (para fechar as notificações - dismissed_at)
DROP POLICY IF EXISTS "notifications_caretaker_update" ON public.notifications;
CREATE POLICY "notifications_caretaker_update"
ON public.notifications FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.senior_caretaker sc
    WHERE sc.id_caretaker = private.get_my_user_id()
      AND sc.id_senior = public.notifications.id_senior
  )
  OR id_caretaker = private.get_my_user_id()
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.senior_caretaker sc
    WHERE sc.id_caretaker = private.get_my_user_id()
      AND sc.id_senior = public.notifications.id_senior
  )
  OR id_caretaker = private.get_my_user_id()
);
