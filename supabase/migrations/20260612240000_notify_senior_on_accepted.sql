-- ============================================================
-- Trigger: Notificar Sénior quando o seu pedido for aceite
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_senior_on_request_accepted()
RETURNS TRIGGER AS $$
DECLARE
  accepter_name text;
BEGIN
  -- Se o estado mudou para ACCEPTED
  IF NEW.state = 'ACCEPTED' AND OLD.state != 'ACCEPTED' THEN
    
    -- Tentar obter o nome de quem aceitou (Voluntário ou Cuidador)
    -- Num pedido público, quem aceita é o id_volunteer
    IF NEW.id_volunteer IS NOT NULL THEN
      SELECT name INTO accepter_name FROM public.users WHERE id = NEW.id_volunteer;
    -- Se não for público, quem aceita é o id_caretaker
    ELSIF NEW.id_caretaker IS NOT NULL THEN
      SELECT name INTO accepter_name FROM public.users WHERE id = NEW.id_caretaker;
    END IF;

    -- Inserir notificação destinada ao Sénior
    INSERT INTO public.notifications (type, description, id_senior)
    VALUES (
      'accepted_request',
      'O seu pedido de ' || COALESCE(NEW.category, 'ajuda') || ' foi aceite por ' || COALESCE(accepter_name, 'um voluntário') || '!',
      NEW.id_senior
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_request_accepted ON public.requests;
CREATE TRIGGER on_request_accepted
AFTER UPDATE OF state ON public.requests
FOR EACH ROW
EXECUTE FUNCTION public.notify_senior_on_request_accepted();
