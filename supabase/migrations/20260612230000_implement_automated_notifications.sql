-- ============================================================
-- 1. Atualizar função de Push para suportar o SÉNIOR
-- ============================================================
CREATE OR REPLACE FUNCTION public.send_expo_push_notification()
RETURNS TRIGGER AS $$
DECLARE
  user_push_token text;
  payload jsonb;
BEGIN
  -- Tentar obter token do cuidador (alertas e pedidos)
  IF NEW.id_caretaker IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_caretaker;
  END IF;

  -- Tentar obter token do sénior (ex: lembretes de medicação)
  IF user_push_token IS NULL AND NEW.id_senior IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_senior;
  END IF;

  -- Tentar obter token do voluntário
  IF user_push_token IS NULL AND NEW.id_volunteer IS NOT NULL THEN
    SELECT push_token INTO user_push_token FROM public.users WHERE id = NEW.id_volunteer;
  END IF;

  IF user_push_token IS NOT NULL THEN
    payload := json_build_object(
      'to',    user_push_token,
      'sound', 'default',
      'title', CASE 
                 WHEN NEW.type = 'medication' THEN '💊 Lembrete de Medicação'
                 WHEN NEW.type = 'alert' THEN '🚨 Alerta de Segurança'
                 WHEN NEW.type = 'request' THEN '🔔 Novo Pedido'
                 ELSE '🔔 Geras'
               END,
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

-- Reativar o trigger para abranger 'medication' e 'request' (além de 'alert')
DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (NEW.type IN ('alert', 'medication', 'request'))
EXECUTE FUNCTION public.send_expo_push_notification();


-- ============================================================
-- 2. Pedidos do Sénior para o Cuidador
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_caretaker_on_senior_request()
RETURNS TRIGGER AS $$
BEGIN
  -- Se o pedido for feito com um cuidador atribuído e não for público
  IF NEW.id_caretaker IS NOT NULL AND (NEW.is_public IS FALSE OR NEW.is_public IS NULL) THEN
    INSERT INTO public.notifications (type, description, id_caretaker, id_senior)
    VALUES (
      'request',
      COALESCE(NEW.category, 'Novo pedido de ajuda do seu sénior'),
      NEW.id_caretaker,
      NEW.id_senior
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_private_request_insert ON public.requests;
CREATE TRIGGER on_private_request_insert
AFTER INSERT ON public.requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_caretaker_on_senior_request();


-- ============================================================
-- 3. Alertas de Sensores (ex: movimento de madrugada)
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_caretaker_on_abnormal_sensor()
RETURNS TRIGGER AS $$
DECLARE
  sensor_record RECORD;
  is_abnormal BOOLEAN := FALSE;
  current_hour INTEGER;
BEGIN
  -- Extrair a hora atual
  current_hour := EXTRACT(HOUR FROM CURRENT_TIMESTAMP);

  -- Regras de anomalia (exemplo)
  IF NEW.type = 'motion' AND (current_hour >= 0 AND current_hour <= 5) THEN
    -- Movimento detetado de madrugada (entre meia-noite e 5h)
    is_abnormal := TRUE;
  ELSIF NEW.value ILIKE '%alarm%' OR NEW.value ILIKE '%danger%' THEN
    -- String explicita de alarme
    is_abnormal := TRUE;
  END IF;

  IF is_abnormal THEN
    -- Obter os dados do sensor para saber quem avisar
    SELECT id_caretaker, id_senior INTO sensor_record 
    FROM public.sensors 
    WHERE id = NEW.id_sensor;

    IF FOUND AND sensor_record.id_caretaker IS NOT NULL THEN
      INSERT INTO public.notifications (type, description, id_caretaker, id_senior)
      VALUES (
        'alert',
        'Alerta de Sensor: Atividade invulgar detetada (' || NEW.type || ')',
        sensor_record.id_caretaker,
        sensor_record.id_senior
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_sensor_reading_insert ON public.sensor_readings;
CREATE TRIGGER on_sensor_reading_insert
AFTER INSERT ON public.sensor_readings
FOR EACH ROW
EXECUTE FUNCTION public.notify_caretaker_on_abnormal_sensor();


-- ============================================================
-- 4. Medicação (pg_cron)
-- ============================================================
-- Ativar extensão pg_cron se não existir (necessário privilégio)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Função que procura medicação para tomar AGORA
CREATE OR REPLACE FUNCTION public.check_medications()
RETURNS void AS $$
BEGIN
  INSERT INTO public.notifications (type, description, id_senior)
  SELECT 
    'medication',
    'Está na hora de tomar: ' || name,
    id_senior
  FROM public.medicine
  WHERE status = 'TO TAKE'
    -- Se houvesse formato HH:MM e estivessemos no mesmo minuto
    AND scheduled_time = to_char(CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Lisbon', 'HH24:MI')
    -- E estiver dentro do periodo de tratamento
    AND (start_date IS NULL OR start_date::date <= CURRENT_DATE)
    AND (end_date IS NULL OR end_date::date >= CURRENT_DATE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Agendar a função para correr a cada minuto (se o pg_cron estiver ativo)
DO $$
BEGIN
  -- Isto cria ou atualiza o cron job
  PERFORM cron.schedule(
    'check_medications_every_minute',
    '* * * * *',
    'SELECT public.check_medications();'
  );
EXCEPTION WHEN OTHERS THEN
  -- Caso o utilizador não tenha permissões para pg_cron, ignora silenciosamente.
  RAISE NOTICE 'pg_cron not available or permission denied.';
END $$;
