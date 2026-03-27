-- ═══════════════════════════════════════════════════════════════
-- DEMO DATA: Fill a warehouse with realistic presentation data
-- Run this in Supabase Dashboard → SQL Editor
-- Auto-discovers the first active company & warehouse.
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_company_id UUID;
  v_warehouse_id UUID;
  v_warehouse_name TEXT;
  v_employee_id UUID;
  v_employee_name TEXT;
  
  -- Category IDs
  cat_electronics UUID := gen_random_uuid();
  cat_accessories UUID := gen_random_uuid();
  cat_food UUID := gen_random_uuid();
  cat_office UUID := gen_random_uuid();
  cat_household UUID := gen_random_uuid();
  
  -- Product IDs
  p1 UUID := gen_random_uuid();  p2 UUID := gen_random_uuid();
  p3 UUID := gen_random_uuid();  p4 UUID := gen_random_uuid();
  p5 UUID := gen_random_uuid();  p6 UUID := gen_random_uuid();
  p7 UUID := gen_random_uuid();  p8 UUID := gen_random_uuid();
  p9 UUID := gen_random_uuid();  p10 UUID := gen_random_uuid();
  p11 UUID := gen_random_uuid(); p12 UUID := gen_random_uuid();
  p13 UUID := gen_random_uuid(); p14 UUID := gen_random_uuid();
  p15 UUID := gen_random_uuid(); p16 UUID := gen_random_uuid();
  p17 UUID := gen_random_uuid(); p18 UUID := gen_random_uuid();
  p19 UUID := gen_random_uuid(); p20 UUID := gen_random_uuid();
  
  -- Sale IDs
  s1 UUID := gen_random_uuid(); s2 UUID := gen_random_uuid();
  s3 UUID := gen_random_uuid(); s4 UUID := gen_random_uuid();
  s5 UUID := gen_random_uuid(); s6 UUID := gen_random_uuid();
  s7 UUID := gen_random_uuid(); s8 UUID := gen_random_uuid();
  
  -- Arrival IDs
  a1 UUID := gen_random_uuid(); a2 UUID := gen_random_uuid();
  a3 UUID := gen_random_uuid();

BEGIN
  -- ─── Auto-discover company & warehouse ───
  SELECT id INTO v_company_id FROM companies WHERE is_active = true LIMIT 1;
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'No active company found!';
  END IF;
  
  SELECT id, name INTO v_warehouse_id, v_warehouse_name
  FROM warehouses WHERE company_id = v_company_id AND is_active = true LIMIT 1;
  IF v_warehouse_id IS NULL THEN
    RAISE EXCEPTION 'No active warehouse found!';
  END IF;
  
  -- Try to find an employee
  SELECT id, name INTO v_employee_id, v_employee_name
  FROM employees WHERE company_id = v_company_id AND is_active = true LIMIT 1;
  
  RAISE NOTICE 'Using company: %, warehouse: % (%)', v_company_id, v_warehouse_name, v_warehouse_id;

  -- ═══════════════════════════════════════════
  -- CATEGORIES
  -- ═══════════════════════════════════════════
  INSERT INTO categories (id, company_id, name, sort_order, created_at) VALUES
    (cat_electronics, v_company_id, 'Электроника',     1, NOW()),
    (cat_accessories, v_company_id, 'Аксессуары',      2, NOW()),
    (cat_food,        v_company_id, 'Продукты',        3, NOW()),
    (cat_office,      v_company_id, 'Канцелярия',      4, NOW()),
    (cat_household,   v_company_id, 'Бытовые товары',  5, NOW());

  -- ═══════════════════════════════════════════
  -- PRODUCTS (20 items with realistic data)
  -- ═══════════════════════════════════════════
  INSERT INTO products (id, company_id, warehouse_id, category_id, name, sku, barcode, description, cost_price, selling_price, quantity, unit, min_stock, max_stock, sold_last_30_days, days_of_stock_left, stock_zone, image_url, is_public, created_at, updated_at) VALUES
    -- Электроника (5)
    (p1,  v_company_id, v_warehouse_id, cat_electronics, 'iPhone 15 Pro 256GB',      'IP15P-256', '8901234567001', 'Смартфон Apple iPhone 15 Pro, 256GB, титановый',                    420000, 530000,  8,  'шт', 3, 30, 12, 20.0, 'normal', 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400', true, NOW() - INTERVAL '45 days', NOW()),
    (p2,  v_company_id, v_warehouse_id, cat_electronics, 'Samsung Galaxy S24 Ultra',  'SGS24U',    '8901234567002', 'Смартфон Samsung Galaxy S24 Ultra, 512GB',                          380000, 480000,  5,  'шт', 2, 20, 8,  18.7, 'normal', 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=400', true, NOW() - INTERVAL '30 days', NOW()),
    (p3,  v_company_id, v_warehouse_id, cat_electronics, 'AirPods Pro 2',             'APP2',      '8901234567003', 'Беспроводные наушники Apple AirPods Pro 2-го поколения',             55000,  75000,   15, 'шт', 5, 50, 22, 20.4, 'normal', 'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?w=400', true, NOW() - INTERVAL '60 days', NOW()),
    (p4,  v_company_id, v_warehouse_id, cat_electronics, 'MacBook Air M3',            'MBA-M3',    '8901234567004', 'Ноутбук Apple MacBook Air 15" M3, 8GB RAM, 256GB SSD',              600000, 750000,  3,  'шт', 1, 10, 4,  22.5, 'warning','https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400', true, NOW() - INTERVAL '90 days', NOW()),
    (p5,  v_company_id, v_warehouse_id, cat_electronics, 'JBL Charge 5',              'JBLC5',     '8901234567005', 'Портативная колонка JBL Charge 5, водонепроницаемая',                35000,  48000,   20, 'шт', 5, 40, 15, 40.0, 'good',   'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400', true, NOW() - INTERVAL '40 days', NOW()),

    -- Аксессуары (5)
    (p6,  v_company_id, v_warehouse_id, cat_accessories, 'Чехол iPhone 15 Pro кожаный', 'CASE-15P', '8901234567006', 'Кожаный чехол для iPhone 15 Pro, чёрный',                         4500,   8500,    35, 'шт', 10, 100, 28, 37.5, 'good',   'https://images.unsplash.com/photo-1601593346740-925612772716?w=400', true, NOW() - INTERVAL '20 days', NOW()),
    (p7,  v_company_id, v_warehouse_id, cat_accessories, 'Кабель USB-C Lightning 2м',   'USBC-L2',  '8901234567007', 'Кабель для зарядки USB-C to Lightning, 2 метра',                    1200,   2500,    50, 'шт', 15, 200, 45, 33.3, 'good',   'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400', true, NOW() - INTERVAL '25 days', NOW()),
    (p8,  v_company_id, v_warehouse_id, cat_accessories, 'Защитное стекло Samsung S24',  'ZS-S24',   '8901234567008', 'Защитное стекло 9H для Samsung Galaxy S24 Ultra',                   800,    2000,    60, 'шт', 20, 200, 35, 51.4, 'good',   'https://images.unsplash.com/photo-1530319067432-f2a729c03db5?w=400', true, NOW() - INTERVAL '15 days', NOW()),
    (p9,  v_company_id, v_warehouse_id, cat_accessories, 'Power Bank 20000 mAh',         'PB-20K',   '8901234567009', 'Портативный аккумулятор 20000mAh, USB-C, быстрая зарядка',          8000,   14000,   18, 'шт', 5, 50, 20, 27.0, 'normal', 'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=400', true, NOW() - INTERVAL '35 days', NOW()),
    (p10, v_company_id, v_warehouse_id, cat_accessories, 'Зарядное устройство 65W',      'ZU-65W',   '8901234567010', 'Быстрое зарядное устройство GaN 65W, 3 порта',                     5500,   9500,    25, 'шт', 8, 60, 18, 41.7, 'good',   'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=400', true, NOW() - INTERVAL '50 days', NOW()),

    -- Продукты (4)
    (p11, v_company_id, v_warehouse_id, cat_food, 'Кофе Lavazza Oro 1кг',       'COFFEE-LV', '8901234567011', 'Кофе в зёрнах Lavazza Qualità Oro, 1 кг',                           4500,  7200,    30, 'шт', 10, 80, 40, 22.5, 'normal', 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400', true, NOW() - INTERVAL '10 days', NOW()),
    (p12, v_company_id, v_warehouse_id, cat_food, 'Чай Ahmad Earl Grey 200г',   'TEA-AH',    '8901234567012', 'Чай чёрный Ahmad Tea Earl Grey, 200г',                              1200,  2100,    45, 'шт', 15, 100, 30, 45.0, 'good',   'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400', true, NOW() - INTERVAL '12 days', NOW()),
    (p13, v_company_id, v_warehouse_id, cat_food, 'Шоколад Lindt Excellence 85%','CHOC-LD',   '8901234567013', 'Тёмный шоколад Lindt Excellence 85% какао, 100г',                   850,   1600,    70, 'шт', 20, 150, 55, 38.2, 'good',   'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=400', true, NOW() - INTERVAL '8 days',  NOW()),
    (p14, v_company_id, v_warehouse_id, cat_food, 'Мёд натуральный 500г',       'HONEY-500', '8901234567014', 'Мёд натуральный цветочный, стекло, 500г',                           1800,  3200,    22, 'шт', 8, 60, 18, 36.7, 'good',   'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400', true, NOW() - INTERVAL '20 days', NOW()),

    -- Канцелярия (3)
    (p15, v_company_id, v_warehouse_id, cat_office, 'Блокнот Moleskine A5',     'NB-MOL-A5', '8901234567015', 'Блокнот Moleskine Classic, A5, линейка, чёрный',                    3500,  6200,    12, 'шт', 5, 40, 10, 36.0, 'good',   'https://images.unsplash.com/photo-1531346878377-a5be20888e57?w=400', true, NOW() - INTERVAL '30 days', NOW()),
    (p16, v_company_id, v_warehouse_id, cat_office, 'Набор ручек Parker',       'PEN-PRK',   '8901234567016', 'Набор шариковых ручек Parker Jotter, 3шт',                          4200,  7500,    8,  'шт', 3, 25, 6,  40.0, 'good',   'https://images.unsplash.com/photo-1585336261022-680e295ce3fe?w=400', true, NOW() - INTERVAL '55 days', NOW()),
    (p17, v_company_id, v_warehouse_id, cat_office, 'Степлер Leitz NeXXt',      'STPL-LZ',   '8901234567017', 'Степлер Leitz NeXXt, до 30 листов, синий',                          2800,  4500,    15, 'шт', 5, 30, 8,  56.3, 'good',   'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=400', true, NOW() - INTERVAL '65 days', NOW()),

    -- Бытовые товары (3)
    (p18, v_company_id, v_warehouse_id, cat_household, 'Настольная лампа LED',     'LAMP-LED',  '8901234567018', 'Настольная LED лампа с регулировкой яркости и температуры',          12000, 19500,   10, 'шт', 3, 20, 7,  42.9, 'good',   'https://images.unsplash.com/photo-1507473885765-e6ed057ab6fe?w=400', true, NOW() - INTERVAL '40 days', NOW()),
    (p19, v_company_id, v_warehouse_id, cat_household, 'Органайзер для стола',      'ORG-DESK',  '8901234567019', 'Органайзер для рабочего стола, бамбук, 4 секции',                   3500,  5800,    20, 'шт', 5, 40, 12, 50.0, 'good',   'https://images.unsplash.com/photo-1544816155-12df9643f363?w=400', true, NOW() - INTERVAL '25 days', NOW()),
    (p20, v_company_id, v_warehouse_id, cat_household, 'Термокружка Stanley 0.47л', 'THERM-ST',  '8901234567020', 'Термокружка Stanley Classic, 0.47л, нержавеющая сталь, зелёная',    8500,  14500,   14, 'шт', 4, 30, 16, 26.3, 'normal', 'https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?w=400', true, NOW() - INTERVAL '18 days', NOW());

  -- ═══════════════════════════════════════════
  -- ARRIVALS (3 прихода за последний месяц)
  -- ═══════════════════════════════════════════
  INSERT INTO arrivals (id, company_id, employee_id, warehouse_id, supplier, status, total_amount, notes, created_at, updated_at) VALUES
    (a1, v_company_id, v_employee_id, v_warehouse_id, 'Apple Kazakhstan',    'completed', 4680000, 'Приход электроники Apple — основной заказ',       NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days'),
    (a2, v_company_id, v_employee_id, v_warehouse_id, 'Samsung Distribution','completed', 2180000, 'Приход Samsung + аксессуары',                      NOW() - INTERVAL '20 days', NOW() - INTERVAL '20 days'),
    (a3, v_company_id, v_employee_id, v_warehouse_id, 'ТОО "Оптовик"',      'completed', 350000,  'Продукты питания и канцелярия — еженедельный заказ', NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days');

  -- Arrival items
  INSERT INTO arrival_items (id, arrival_id, product_id, product_name, quantity, cost_price, selling_price, created_at) VALUES
    -- Приход 1: Apple
    (gen_random_uuid(), a1, p1, 'iPhone 15 Pro 256GB',  10, 420000, 530000, NOW() - INTERVAL '30 days'),
    (gen_random_uuid(), a1, p3, 'AirPods Pro 2',        20, 55000,  75000,  NOW() - INTERVAL '30 days'),
    (gen_random_uuid(), a1, p4, 'MacBook Air M3',        5, 600000, 750000, NOW() - INTERVAL '30 days'),
    -- Приход 2: Samsung + аксессуары  
    (gen_random_uuid(), a2, p2, 'Samsung Galaxy S24 Ultra', 8, 380000, 480000, NOW() - INTERVAL '20 days'),
    (gen_random_uuid(), a2, p8, 'Защитное стекло Samsung S24', 80, 800, 2000,  NOW() - INTERVAL '20 days'),
    (gen_random_uuid(), a2, p9, 'Power Bank 20000 mAh',     25, 8000, 14000,   NOW() - INTERVAL '20 days'),
    (gen_random_uuid(), a2, p10,'Зарядное устройство 65W',   30, 5500, 9500,   NOW() - INTERVAL '20 days'),
    -- Приход 3: Продукты + канцелярия
    (gen_random_uuid(), a3, p11, 'Кофе Lavazza Oro 1кг',      40, 4500, 7200,  NOW() - INTERVAL '10 days'),
    (gen_random_uuid(), a3, p13, 'Шоколад Lindt Excellence',   80, 850,  1600,  NOW() - INTERVAL '10 days'),
    (gen_random_uuid(), a3, p15, 'Блокнот Moleskine A5',       15, 3500, 6200,  NOW() - INTERVAL '10 days');

  -- ═══════════════════════════════════════════
  -- SALES (8 продаж за последние 2 недели)
  -- ═══════════════════════════════════════════
  INSERT INTO sales (id, company_id, employee_id, warehouse_id, total_amount, discount_amount, payment_method, status, notes, created_at, updated_at) VALUES
    (s1, v_company_id, v_employee_id, v_warehouse_id, 538500, 0,     'card',     'completed', 'Клиент — Ахмет К.',         NOW() - INTERVAL '13 days', NOW() - INTERVAL '13 days'),
    (s2, v_company_id, v_employee_id, v_warehouse_id, 89500,  4500,  'cash',     'completed', 'Скидка постоянному клиенту', NOW() - INTERVAL '11 days', NOW() - INTERVAL '11 days'),
    (s3, v_company_id, v_employee_id, v_warehouse_id, 480000, 0,     'card',     'completed', 'Продажа Samsung',           NOW() - INTERVAL '9 days',  NOW() - INTERVAL '9 days'),
    (s4, v_company_id, v_employee_id, v_warehouse_id, 28000,  0,     'cash',     'completed', '',                          NOW() - INTERVAL '7 days',  NOW() - INTERVAL '7 days'),
    (s5, v_company_id, v_employee_id, v_warehouse_id, 750000, 15000, 'card',     'completed', 'MacBook — корпоративный клиент', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
    (s6, v_company_id, v_employee_id, v_warehouse_id, 16800,  0,     'cash',     'completed', 'Мелкие покупки',            NOW() - INTERVAL '3 days',  NOW() - INTERVAL '3 days'),
    (s7, v_company_id, v_employee_id, v_warehouse_id, 148000, 0,     'card',     'completed', '',                          NOW() - INTERVAL '2 days',  NOW() - INTERVAL '2 days'),
    (s8, v_company_id, v_employee_id, v_warehouse_id, 42200,  2000,  'kaspi',    'completed', 'Оплата через Kaspi QR',     NOW() - INTERVAL '1 day',   NOW() - INTERVAL '1 day');

  -- Sale items
  INSERT INTO sale_items (id, sale_id, product_id, product_name, quantity, selling_price, cost_price, discount_amount, created_at) VALUES
    -- Sale 1: iPhone + чехол + стекло
    (gen_random_uuid(), s1, p1, 'iPhone 15 Pro 256GB',       1, 530000, 420000, 0, NOW() - INTERVAL '13 days'),
    (gen_random_uuid(), s1, p6, 'Чехол iPhone 15 Pro кожаный',1, 8500,  4500,   0, NOW() - INTERVAL '13 days'),
    -- Sale 2: AirPods + кабель + кофе
    (gen_random_uuid(), s2, p3, 'AirPods Pro 2',             1, 75000,  55000,  3000, NOW() - INTERVAL '11 days'),
    (gen_random_uuid(), s2, p7, 'Кабель USB-C Lightning 2м', 2, 2500,   1200,   500,  NOW() - INTERVAL '11 days'),
    (gen_random_uuid(), s2, p11,'Кофе Lavazza Oro 1кг',      1, 7200,   4500,   1000, NOW() - INTERVAL '11 days'),
    -- Sale 3: Samsung
    (gen_random_uuid(), s3, p2, 'Samsung Galaxy S24 Ultra',  1, 480000, 380000, 0, NOW() - INTERVAL '9 days'),
    -- Sale 4: Повербанк + зарядка
    (gen_random_uuid(), s4, p9, 'Power Bank 20000 mAh',      1, 14000,  8000,  0, NOW() - INTERVAL '7 days'),
    (gen_random_uuid(), s4, p10,'Зарядное устройство 65W',    1, 9500,  5500,   0, NOW() - INTERVAL '7 days'),
    (gen_random_uuid(), s4, p7, 'Кабель USB-C Lightning 2м',  2, 2500,  1200,   0, NOW() - INTERVAL '7 days'),
    -- Sale 5: MacBook
    (gen_random_uuid(), s5, p4, 'MacBook Air M3',            1, 750000, 600000, 15000, NOW() - INTERVAL '5 days'),
    -- Sale 6: Мелкие товары
    (gen_random_uuid(), s6, p13,'Шоколад Lindt Excellence',   3,  1600,  850,  0, NOW() - INTERVAL '3 days'),
    (gen_random_uuid(), s6, p12,'Чай Ahmad Earl Grey',        2,  2100,  1200, 0, NOW() - INTERVAL '3 days'),
    (gen_random_uuid(), s6, p14,'Мёд натуральный 500г',       2,  3200,  1800, 0, NOW() - INTERVAL '3 days'),
    -- Sale 7: JBL + AirPods
    (gen_random_uuid(), s7, p5, 'JBL Charge 5',              1, 48000,  35000, 0, NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), s7, p3, 'AirPods Pro 2',             1, 75000,  55000, 0, NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), s7, p7, 'Кабель USB-C Lightning 2м', 2, 2500,   1200,  0, NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), s7, p8, 'Защитное стекло Samsung S24',3, 2000,   800,  0, NOW() - INTERVAL '2 days'),
    -- Sale 8: Канцелярия + термо
    (gen_random_uuid(), s8, p15,'Блокнот Moleskine A5',       1, 6200,  3500, 500,  NOW() - INTERVAL '1 day'),
    (gen_random_uuid(), s8, p16,'Набор ручек Parker',         1, 7500,  4200, 500,  NOW() - INTERVAL '1 day'),
    (gen_random_uuid(), s8, p20,'Термокружка Stanley',        2, 14500, 8500, 1000, NOW() - INTERVAL '1 day');

  RAISE NOTICE '✅ Demo data inserted! Company: %, Warehouse: %', v_company_id, v_warehouse_name;
  RAISE NOTICE '📦 20 products in 5 categories';
  RAISE NOTICE '📥 3 arrivals with 10 items total';
  RAISE NOTICE '💰 8 sales with 20 items total';

END $$;
