-- Permitir que o Sénior marque as suas próprias notificações como dispensadas (dismissed_at)
-- Só pode atualizar notificações onde é o id_senior — e apenas o campo dismissed_at
DROP POLICY IF EXISTS "notifications_senior_dismiss" ON public.notifications;
CREATE POLICY "notifications_senior_dismiss"
ON public.notifications FOR UPDATE TO authenticated
USING (
  id_senior = private.get_my_user_id()
)
WITH CHECK (
  id_senior = private.get_my_user_id()
);
