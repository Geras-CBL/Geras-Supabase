-- 1. Remover triggers antigos que enviavam push direto por SQL
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
DROP TRIGGER IF EXISTS on_request_notification_insert ON public.notifications;

-- 2. Modificar a função notify_volunteers_on_public_request para NÃO fazer HTTP POST direto da base de dados
-- Ela passa a apenas inserir o registo de notificação na base de dados
CREATE OR REPLACE FUNCTION public.notify_volunteers_on_public_request()
RETURNS TRIGGER AS $$
DECLARE
  vol RECORD;
  request_description text;
BEGIN
  IF TG_OP = 'UPDATE' AND (OLD.is_public IS TRUE) THEN
    RETURN NEW;
  END IF;

  IF NEW.is_public IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  request_description := COALESCE(
    NEW.description,
    NEW.category,
    'Novo pedido de ajuda na comunidade'
  );

  FOR vol IN
    SELECT id, push_token
    FROM public.users
    WHERE role = 'VOLUNTEER'
      AND push_token IS NOT NULL
      AND push_token <> ''
  LOOP
    -- Apenas inserimos na tabela de notificações.
    -- O Webhook tratará de enviar a push notification individual correspondente.
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

-- 3. Criar a nova função de trigger para chamar a Edge Function via Webhook
CREATE OR REPLACE FUNCTION public.trigger_send_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  payload jsonb;
  webhook_url text;
  webhook_secret text;
BEGIN
  -- Ler configurações customizadas da base de dados (se existirem), caso contrário usar padrão local
  webhook_url := COALESCE(
    current_setting('app.settings.push_webhook_url', true),
    'http://kong:8000/functions/v1/send-push-notification'
  );
  webhook_secret := COALESCE(
    current_setting('app.settings.push_webhook_secret', true),
    'super-secret-webhook-key-123'
  );

  -- Construir o payload padrão do webhook do Supabase
  payload := json_build_object(
    'type', 'INSERT',
    'table', 'notifications',
    'schema', 'public',
    'record', row_to_json(NEW)
  )::jsonb;

  -- Chamar a Edge Function de forma assíncrona usando a extensão pg_net
  PERFORM net.http_post(
    url := webhook_url,
    body := payload,
    headers := json_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    )::jsonb
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Criar o novo trigger que monitoriza inserções na tabela de notificações
DROP TRIGGER IF EXISTS on_notification_insert_webhook ON public.notifications;
CREATE TRIGGER on_notification_insert_webhook
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (NEW.type IN ('alert', 'medication', 'request'))
EXECUTE FUNCTION public.trigger_send_push_notification();
