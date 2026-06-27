-- ─── 048_kitchen_restaurant_support.sql ───
-- Добавление поддержки типов товаров и рецептов для общепита (Кухня)

-- 1. Добавление колонки product_type в таблицу products
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS product_type TEXT DEFAULT 'retail';

-- 2. Создание таблицы рецептов (Технологических карт)
CREATE TABLE IF NOT EXISTS public.recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dish_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  quantity_required NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Включение Row Level Security (RLS) для таблицы рецептов
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

-- 4. Политики безопасности RLS для recipes
CREATE POLICY "Enable read access for all authenticated users" ON public.recipes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Enable write access for all authenticated users" ON public.recipes
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
