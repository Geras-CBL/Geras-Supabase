-- FIX: O trigger estava a sobrescrever o status 'USED' porque dispara em QUALQUER update.
-- Solução: limitar o trigger para só disparar quando current_tasks é alterado.
-- Assim, um UPDATE direto ao status (ex: marcar como USED) não é intercetado.

-- 1) Remover o trigger antigo
DROP TRIGGER IF EXISTS trg_voucher_auto_status ON public.vouchers_volunteer;

-- 2) Recriar o trigger apenas para alterações em current_tasks
CREATE TRIGGER trg_voucher_auto_status
BEFORE UPDATE OF current_tasks ON public.vouchers_volunteer
FOR EACH ROW
EXECUTE FUNCTION public.update_voucher_status();
