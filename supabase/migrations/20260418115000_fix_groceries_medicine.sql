-- Migração para corrigir a associação de groceries e medicine aos utilizadores seniores.

-- 1. Adicionar id_senior à tabela groceries
ALTER TABLE "public"."groceries"
ADD COLUMN IF NOT EXISTS "id_senior" integer;

-- Adicionar a restrição de chave estrangeira
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'groceries_id_senior_fkey'
  ) THEN
    ALTER TABLE "public"."groceries"
      ADD CONSTRAINT "groceries_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;
  END IF;
END $$;

-- 2. Adicionar id_senior à tabela medicine
ALTER TABLE "public"."medicine"
ADD COLUMN IF NOT EXISTS "id_senior" integer;

-- Adicionar a restrição de chave estrangeira
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'medicine_id_senior_fkey'
  ) THEN
    ALTER TABLE "public"."medicine"
      ADD CONSTRAINT "medicine_id_senior_fkey" FOREIGN KEY ("id_senior") REFERENCES "public"."users"("id") ON DELETE CASCADE;
  END IF;
END $$;
