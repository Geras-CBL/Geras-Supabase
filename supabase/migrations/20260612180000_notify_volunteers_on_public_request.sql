-- ============================================================
-- Trigger: notificar todos os voluntários quando um pedido
-- é marcado como público (is_public = true), seja na criação
-- ou no reencaminhamento pelo cuidador.
-- ============================================================

-- Função principal
CREATE OR REPLACE FUNCTION public.notify_volunteers_on_public_request()
RETURNS TRIGGER AS $$
DECLARE
  vol RECORD;
  payload jsonb;
  request_description text;
BEGIN
  -- Só agir quando is_public passa a true
  -- INSERT: NEW.is_public = true
  -- UPDATE: OLD.is_public = false/null → NEW.is_public = true
  IF TG_OP = 'UPDATE' AND (OLD.is_public IS TRUE) THEN
    RETURN NEW; -- já era público, não repetir
  END IF;

  IF NEW.is_public IS NOT TRUE THEN
    RETURN NEW; -- não é público, ignorar
  END IF;

  -- Texto descritivo para a notificação
  request_description := COALESCE(
    NEW.description,
    NEW.category,
    'Novo pedido de ajuda na comunidade'
  );

  -- Iterar sobre todos os voluntários com push_token registado
  FOR vol IN
    SELECT id, push_token
    FROM public.users
    WHERE role = 'VOLUNTEER'
      AND push_token IS NOT NULL
      AND push_token <> ''
  LOOP
    -- 1. Enviar push notification via Expo API (para quando a app está fechada)
    payload := json_build_object(
      'to',    vol.push_token,
      'sound', 'default',
      'title', '🤝 Novo Pedido de Ajuda',
      'body',  request_description,
      'data',  json_build_object('requestId', NEW.id, 'screen', 'HomePage')
    )::jsonb;

    PERFORM extensions.net.http_post(
      url     := 'https://exp.host/--/api/v2/push/send',
      body    := payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );

    -- 2. Inserir na tabela notifications (para realtime dentro da app)
    INSERT INTO public.notifications (type, description, id_volunteer, id_senior, id_caretaker)
    VALUES (
      'request',
      request_description,
      vol.id,
      NEW.id_senior,
      NEW.id_caretaker
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remover triggers antigos se existirem
DROP TRIGGER IF EXISTS on_request_public_insert ON public.requests;
DROP TRIGGER IF EXISTS on_request_public_update ON public.requests;

-- Trigger no INSERT (pedido criado diretamente como público)
CREATE TRIGGER on_request_public_insert
AFTER INSERT ON public.requests
FOR EACH ROW
WHEN (NEW.is_public IS TRUE)
EXECUTE FUNCTION public.notify_volunteers_on_public_request();

-- Trigger no UPDATE (cuidador reencaminha → is_public muda para true)
CREATE TRIGGER on_request_public_update
AFTER UPDATE OF is_public ON public.requests
FOR EACH ROW
WHEN (NEW.is_public IS TRUE AND (OLD.is_public IS FALSE OR OLD.is_public IS NULL))
EXECUTE FUNCTION public.notify_volunteers_on_public_request();

-- Garantir que os voluntários podem ver as suas próprias notificações
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications'
      AND policyname = 'notifications_volunteer_select_own'
  ) THEN
    CREATE POLICY "notifications_volunteer_select_own"
    ON public.notifications FOR SELECT TO authenticated
    USING (
      id_volunteer = (
        SELECT id FROM public.users
        WHERE auth_user_id = auth.uid()
        LIMIT 1
      )
    );
  END IF;
END $$;
