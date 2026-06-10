-- Ativar a extensão pg_net (necessária para fazer pedidos HTTP)
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

-- Criar a função que envia a notificação para a Expo
CREATE OR REPLACE FUNCTION public.send_expo_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  user_push_token text;
  payload jsonb;
BEGIN
  -- Obter o push_token do utilizador que deve receber a notificação
  -- Assumimos que a notificação tem um id_caretaker como destino
  IF NEW.id_caretaker IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_caretaker;
  END IF;

  -- Se encontrarmos o token, fazemos o POST request para a API da Expo
  IF user_push_token IS NOT NULL THEN
    payload := json_build_object(
      'to', user_push_token,
      'sound', 'default',
      'title', '🔔 Novo Alerta Geras',
      'body', NEW.description
    )::jsonb;

    PERFORM net.http_post(
      url:='https://exp.host/--/api/v2/push/send',
      body:=payload,
      headers:='{"Content-Type": "application/json"}'::jsonb
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Criar o trigger que reage aos inserts na tabela notifications
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (NEW.type = 'alert')
EXECUTE FUNCTION public.send_expo_push_notification();
