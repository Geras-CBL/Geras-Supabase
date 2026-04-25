-- ==============================================================
-- MIGRATION: Allow Anon Access to Groceries & Fix Sequence
-- ==============================================================

-- 1) Fix groceries ID sequence 
-- (This fixes the "duplicate key value violates unique constraint" error
-- when inserting new items, caused by manual insertions with hardcoded IDs)
SELECT setval('groceries_id_seq', COALESCE((SELECT MAX(id) FROM public.groceries), 1), true);

-- 2) Update RLS policies to allow anon users to select/insert groceries
-- This is necessary because the prototype frontend does not implement a full login system yet.

-- SELECT for groceries
DROP POLICY IF EXISTS "groceries_anon_select" ON public.groceries;
CREATE POLICY "groceries_anon_select" ON public.groceries FOR SELECT TO anon USING (true);

-- INSERT for groceries
DROP POLICY IF EXISTS "groceries_anon_insert" ON public.groceries;
CREATE POLICY "groceries_anon_insert" ON public.groceries FOR INSERT TO anon WITH CHECK (true);

-- SELECT for senior_groceries
DROP POLICY IF EXISTS "senior_groceries_anon_select" ON public.senior_groceries;
CREATE POLICY "senior_groceries_anon_select" ON public.senior_groceries FOR SELECT TO anon USING (true);

-- INSERT for senior_groceries
DROP POLICY IF EXISTS "senior_groceries_anon_insert" ON public.senior_groceries;
CREATE POLICY "senior_groceries_anon_insert" ON public.senior_groceries FOR INSERT TO anon WITH CHECK (true);

-- UPDATE for senior_groceries
DROP POLICY IF EXISTS "senior_groceries_anon_update" ON public.senior_groceries;
CREATE POLICY "senior_groceries_anon_update" ON public.senior_groceries FOR UPDATE TO anon USING (true);

-- DELETE for senior_groceries
DROP POLICY IF EXISTS "senior_groceries_anon_delete" ON public.senior_groceries;
CREATE POLICY "senior_groceries_anon_delete" ON public.senior_groceries FOR DELETE TO anon USING (true);
