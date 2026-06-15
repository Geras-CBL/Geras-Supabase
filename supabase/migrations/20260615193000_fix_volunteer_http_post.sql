-- ============================================================
-- Fix: Replace extensions.net.http_post with net.http_post
-- ============================================================

CREATE OR REPLACE FUNCTION public.notify_volunteers_on_public_request()
RETURNS TRIGGER AS $$
DECLARE
  vol RECORD;
  payload jsonb;
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
    payload := json_build_object(
      'to',    vol.push_token,
      'sound', 'default',
      'title', '🤝 Novo Pedido de Ajuda',
      'body',  request_description,
      'data',  json_build_object('requestId', NEW.id, 'screen', 'HomePage')
    )::jsonb;

    PERFORM net.http_post(
      url     := 'https://exp.host/--/api/v2/push/send',
      body    := payload,
      headers := '{"Content-Type": "application/json"}'::jsonb
    );

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
