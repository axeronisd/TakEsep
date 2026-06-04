-- Создание таблицы для зон экосистемы
CREATE TABLE public.ecosystem_zones (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    name text NOT NULL,
    center_lat double precision NOT NULL,
    center_lng double precision NOT NULL,
    radius_km double precision NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (id)
);

-- Настройка безопасности (RLS)
ALTER TABLE public.ecosystem_zones ENABLE ROW LEVEL SECURITY;

-- Все могут читать
CREATE POLICY "Enable read access for all users" ON public.ecosystem_zones
    AS PERMISSIVE FOR SELECT
    TO public
    USING (true);

-- Только авторизованные (например, админы) могут изменять (упрощенная политика для старта)
CREATE POLICY "Enable insert for authenticated users only" ON public.ecosystem_zones
    AS PERMISSIVE FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users only" ON public.ecosystem_zones
    AS PERMISSIVE FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users only" ON public.ecosystem_zones
    AS PERMISSIVE FOR DELETE
    TO authenticated
    USING (true);

-- Включение в Realtime
alter publication supabase_realtime add table public.ecosystem_zones;
