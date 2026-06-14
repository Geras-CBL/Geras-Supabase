CREATE TABLE IF NOT EXISTS public.connection_codes (
    code text PRIMARY KEY,
    id_user integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);

ALTER TABLE public.connection_codes ENABLE ROW LEVEL SECURITY;

-- O utilizador que gera pode ver e apagar os seus codigos
CREATE POLICY "connection_codes_select_policy" ON public.connection_codes
    FOR SELECT TO authenticated
    USING (id_user = private.get_my_user_id());

CREATE POLICY "connection_codes_insert_policy" ON public.connection_codes
    FOR INSERT TO authenticated
    WITH CHECK (id_user = private.get_my_user_id());

CREATE POLICY "connection_codes_delete_policy" ON public.connection_codes
    FOR DELETE TO authenticated
    USING (id_user = private.get_my_user_id());

-- Funcao RPC para validar e associar
CREATE OR REPLACE FUNCTION public.associate_with_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_creator_id integer;
    v_creator_role public.user_role;
    v_caller_id integer;
    v_caller_role public.user_role;
    v_senior_id integer;
    v_caretaker_id integer;
BEGIN
    v_caller_id := private.get_my_user_id();

    -- Buscar info do criador do codigo
    SELECT cc.id_user, u.role
    INTO v_creator_id, v_creator_role
    FROM public.connection_codes cc
    JOIN public.users u ON u.id = cc.id_user
    WHERE cc.code = p_code AND cc.expires_at > now();

    IF v_creator_id IS NULL THEN
        RAISE EXCEPTION 'Codigo invalido ou expirado.';
    END IF;

    IF v_creator_id = v_caller_id THEN
        RAISE EXCEPTION 'Nao podes usar o teu proprio codigo.';
    END IF;

    -- Buscar role de quem esta a executar
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

    -- Determinar quem e quem
    IF v_creator_role = 'SENIOR' AND v_caller_role = 'CARETAKER' THEN
        v_senior_id := v_creator_id;
        v_caretaker_id := v_caller_id;
    ELSIF v_creator_role = 'CARETAKER' AND v_caller_role = 'SENIOR' THEN
        v_senior_id := v_caller_id;
        v_caretaker_id := v_creator_id;
    ELSE
        RAISE EXCEPTION 'A associacao deve ser entre um Cuidador e um Senior.';
    END IF;

    -- Inserir na tabela (se ja existir vai ignorar ou dar erro, por isso testamos)
    IF NOT EXISTS (SELECT 1 FROM public.senior_caretaker WHERE id_senior = v_senior_id AND id_caretaker = v_caretaker_id) THEN
        INSERT INTO public.senior_caretaker (id_senior, id_caretaker) VALUES (v_senior_id, v_caretaker_id);
    END IF;

    -- Apagar o codigo para que nao seja reutilizado
    DELETE FROM public.connection_codes WHERE code = p_code;

    RETURN true;
END;
$$;
