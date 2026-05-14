-- Remover os triggers antigos que estão a interferir com as atualizações de status
DROP TRIGGER IF EXISTS trg_update_voucher_status ON public.vouchers_volunteer;
DROP FUNCTION IF EXISTS public.update_voucher_status_on_progress();

-- Garantir que o nosso novo trigger apenas atua quando current_tasks é modificado
DROP TRIGGER IF EXISTS trg_voucher_auto_status ON public.vouchers_volunteer;
CREATE TRIGGER trg_voucher_auto_status
BEFORE UPDATE OF current_tasks ON public.vouchers_volunteer
FOR EACH ROW
EXECUTE FUNCTION public.update_voucher_status();
