-- Migration: Product Modifiers & Modifier Selections

CREATE TABLE IF NOT EXISTS product_modifier_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    min_selections INT DEFAULT 0,
    max_selections INT DEFAULT 1,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_modifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES product_modifier_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price_delta NUMERIC NOT NULL DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delivery_order_item_modifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id UUID REFERENCES sale_items(id) ON DELETE CASCADE,
    modifier_id UUID,
    modifier_name TEXT NOT NULL,
    group_name TEXT NOT NULL,
    price_delta NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
