-- Ensure all existing requests have a description
UPDATE public.requests 
SET description = 'Pedido de ajuda (gerado automaticamente)' 
WHERE description IS NULL OR trim(description) = '';

-- Make the description column NOT NULL
ALTER TABLE public.requests 
ALTER COLUMN description SET NOT NULL;

-- Add check constraint to ensure description is not just empty spaces
ALTER TABLE public.requests 
ADD CONSTRAINT requests_description_check CHECK (char_length(trim(description)) > 0);
