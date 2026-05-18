-- Trigger: quando um pedido é marcado como COMPLETED,
-- incrementar current_tasks em todos os vouchers do voluntário (exceto os já USED)

CREATE OR REPLACE FUNCTION public.increment_voucher_tasks_on_request_complete()
RETURNS TRIGGER AS $$
BEGIN
  -- Só atuar quando o estado muda para COMPLETED
  IF NEW.state = 'COMPLETED' AND (OLD.state IS DISTINCT FROM 'COMPLETED') THEN
    -- Verificar se há um voluntário associado ao pedido
    IF NEW.id_volunteer IS NOT NULL THEN
      -- Incrementar current_tasks em todos os vouchers do voluntário que não estejam USED
      UPDATE public.vouchers_volunteer
      SET current_tasks = current_tasks + 1
      WHERE id_volunteer = NEW.id_volunteer
        AND status != 'USED';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_request_complete_increment_voucher ON public.requests;
CREATE TRIGGER trg_request_complete_increment_voucher
AFTER UPDATE ON public.requests
FOR EACH ROW
EXECUTE FUNCTION public.increment_voucher_tasks_on_request_complete();
