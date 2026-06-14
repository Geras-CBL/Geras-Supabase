CREATE POLICY "senior_caretaker_delete_policy" 
ON public.senior_caretaker 
FOR DELETE 
TO authenticated 
USING (
    id_senior = private.get_my_user_id() OR id_caretaker = private.get_my_user_id()
);
