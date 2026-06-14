-- ============================================================
-- Trigger: enviar push notification a TODOS os voluntários
-- quando é inserida uma notificação com type = 'request'
-- (pedido público / broadcast para a comunidade)
-- ============================================================

-- Função que itera sobre todos os voluntários e envia push
CREATE OR REPLACE FUNCTION public.send_push_to_all_volunteers()
RETURNS TRIGGER AS $$
DECLARE
  vol RECORD;
  payload jsonb;
BEGIN
  -- Iterar sobre todos os voluntários com push_token registado
  FOR vol IN
    SELECT id, push_token
    FROM public.users
    WHERE role = 'VOLUNTEER'
      AND push_token IS NOT NULL
      AND push_token <> ''
  LOOP
    payload := json_build_object(
      'to',    vol.push_token,
      'sound', 'default',
      'title', '🤝 Novo Pedido de Ajuda',
      'body',  COALESCE(NEW.description, 'Há um pedido de ajuda na tua área!'),
      'data',  json_build_object('type', 'request', 'screen', 'HomePage')
    )::jsonb;

    PERFORM net.http_post(
      url     := 'https://exp.host/--/api/v2/push/send',
      body    := payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remover trigger antigo se existir
DROP TRIGGER IF EXISTS on_request_notification_insert ON public.notifications;

-- Novo trigger: dispara para type = 'request'
CREATE TRIGGER on_request_notification_insert
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (NEW.type = 'request')
EXECUTE FUNCTION public.send_push_to_all_volunteers();
