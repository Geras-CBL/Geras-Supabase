-- ============================================================
-- Fix: corrigir a função de push para voluntários
-- Usar net.http_post com a assinatura correta do pg_net
-- e garantir que a extensão está activa no schema correto
-- ============================================================

-- Garantir que pg_net está disponível
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Recriar a função com assinatura correcta do pg_net
CREATE OR REPLACE FUNCTION public.send_push_to_all_volunteers()
RETURNS TRIGGER AS $$
DECLARE
  vol RECORD;
  payload text;
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
      'body',  COALESCE(NEW.description, 'Há um pedido de ajuda na tua área!')
    )::text;

    PERFORM net.http_post(
      url      := 'https://exp.host/--/api/v2/push/send'::text,
      body     := payload::jsonb,
      headers  := '{"Content-Type": "application/json", "Accept": "application/json"}'::jsonb
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recriar trigger (garantir que está activo)
DROP TRIGGER IF EXISTS on_request_notification_insert ON public.notifications;
CREATE TRIGGER on_request_notification_insert
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (NEW.type = 'request')
EXECUTE FUNCTION public.send_push_to_all_volunteers();

-- Também disparar push para type = 'alert' dirigido a voluntário especifico
-- (reutilizar a função existente send_expo_push_notification que já trata id_caretaker)
-- Adicionar suporte a id_volunteer na função existente
CREATE OR REPLACE FUNCTION public.send_expo_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  user_push_token text;
  payload jsonb;
BEGIN
  -- Tentar obter token do cuidador
  IF NEW.id_caretaker IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_caretaker;
  END IF;

  -- Tentar obter token do voluntário se não houver cuidador
  IF user_push_token IS NULL AND NEW.id_volunteer IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_volunteer;
  END IF;

  IF user_push_token IS NOT NULL THEN
    payload := json_build_object(
      'to',    user_push_token,
      'sound', 'default',
      'title', '🔔 Novo Alerta Geras',
      'body',  NEW.description
    )::jsonb;

    PERFORM net.http_post(
      url     := 'https://exp.host/--/api/v2/push/send'::text,
      body    := payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
