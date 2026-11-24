
-- ============================================================
-- ScanIA - ESTRUTURA DO BANCO DE DADOS
-- Plataforma: Supabase / PostgreSQL
-- ============================================================


-- ============================================================
-- 1. TABELA: RECEIPTS (NOTAS FISCAIS)
-- ============================================================

CREATE TABLE public.receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL DEFAULT auth.uid()
        REFERENCES auth.users (id) ON DELETE CASCADE,

    image_path TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'done', 'error')),

    merchant TEXT,
    purchase_date DATE,

    total NUMERIC(12, 2)
        CHECK (total IS NULL OR total > 0),

    category TEXT,
    payment_method TEXT,
    error_message TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- 2. TABELA: RECEIPT_ITEMS (ITENS DAS NOTAS)
-- ============================================================

CREATE TABLE public.receipt_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    receipt_id UUID NOT NULL
        REFERENCES public.receipts (id) ON DELETE CASCADE,

    description TEXT NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL DEFAULT 1,
    unit_price NUMERIC(12, 2),
    total_price NUMERIC(12, 2) NOT NULL
);


-- ============================================================
-- 3. ÍNDICES PARA OTIMIZAÇÃO DAS CONSULTAS
-- ============================================================

CREATE INDEX receipts_user_created_idx
    ON public.receipts (user_id, created_at DESC);

CREATE INDEX receipt_items_receipt_idx
    ON public.receipt_items (receipt_id);


-- ============================================================
-- 4. SEGURANÇA: ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_items ENABLE ROW LEVEL SECURITY;


-- ------------------------------------------------------------
-- 4.1 POLÍTICAS DA TABELA RECEIPTS
-- ------------------------------------------------------------

CREATE POLICY "Notas: ler as próprias"
    ON public.receipts
    FOR SELECT
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);


CREATE POLICY "Notas: criar as próprias"
    ON public.receipts
    FOR INSERT
    TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);


CREATE POLICY "Notas: editar as próprias"
    ON public.receipts
    FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);


CREATE POLICY "Notas: excluir as próprias"
    ON public.receipts
    FOR DELETE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);


-- ------------------------------------------------------------
-- 4.2 POLÍTICA DA TABELA RECEIPT_ITEMS
-- Os itens seguem as permissões do proprietário da nota.
-- ------------------------------------------------------------

CREATE POLICY "Itens: acesso às notas próprias"
    ON public.receipt_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.receipts AS r
            WHERE r.id = receipt_id
              AND r.user_id = (SELECT auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.receipts AS r
            WHERE r.id = receipt_id
              AND r.user_id = (SELECT auth.uid())
        )
    );


-- ============================================================
-- 5. PERMISSÕES DE ACESSO PELA API
-- ============================================================

GRANT SELECT, INSERT, UPDATE, DELETE
    ON public.receipts
    TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
    ON public.receipt_items
    TO authenticated;


-- ============================================================
-- 6. STORAGE: BUCKET PRIVADO PARA FOTOS
-- ============================================================

INSERT INTO storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
VALUES (
    'receipts',
    'receipts',
    FALSE,
    5242880,
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/webp'
    ]
)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- 7. SEGURANÇA DO STORAGE
-- Cada usuário acessa somente sua própria pasta:
-- receipts/<user_id>/arquivo.jpg
-- ============================================================


-- 7.1 Visualizar as próprias fotos

CREATE POLICY "Fotos: ler as próprias"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'receipts'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    );


-- 7.2 Enviar fotos para a própria pasta

CREATE POLICY "Fotos: enviar para a própria pasta"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'receipts'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    );


-- 7.3 Excluir as próprias fotos

CREATE POLICY "Fotos: excluir as próprias"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'receipts'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
    );


-- ============================================================
-- FIM DO SCRIPT - ScanIA
-- ============================================================
