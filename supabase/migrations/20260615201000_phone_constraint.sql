-- Add validation constraint: phone must be exactly 9 digits
ALTER TABLE public.users
ADD CONSTRAINT phone_format CHECK (phone IS NULL OR (phone ~ '^[0-9]{9}$'));
