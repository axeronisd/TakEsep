-- Migration: create_kitchen_customer_order RPC function

CREATE OR REPLACE FUNCTION create_kitchen_customer_order(
  p_warehouse_id UUID,
  p_customer_id UUID,
  p_table_id UUID,
  p_order_type TEXT, -- 'dine_in', 'takeaway'
  p_items JSONB, -- JSON array of items: [{product_id, name, quantity, unit_price, total, modifiers: [...]}]
  p_customer_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_sale_id UUID;
  v_sale_item_id UUID;
  v_item JSONB;
  v_modifier JSONB;
  v_total DECIMAL := 0;
  v_table_name TEXT;
  v_company_id UUID;
BEGIN
  -- 1. Find company_id from warehouse
  SELECT organization_id INTO v_company_id FROM warehouses WHERE id = p_warehouse_id;
  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Company for warehouse % not found', p_warehouse_id;
  END IF;

  -- 2. Determine client_name based on table or order type
  IF p_table_id IS NOT NULL THEN
    SELECT name INTO v_table_name FROM kitchen_tables WHERE id = p_table_id;
  END IF;
  
  IF v_table_name IS NULL THEN
    IF p_order_type = 'takeaway' THEN
      v_table_name := 'На вынос';
    ELSE
      v_table_name := 'Заказ с телефона';
    END IF;
  END IF;

  -- 3. Calculate total amount
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_total := v_total + (v_item->>'total')::DECIMAL;
  END LOOP;

  -- 4. Create sale ticket
  v_sale_id := gen_random_uuid();
  INSERT INTO sales (
    id, company_id, warehouse_id, total_amount, discount_amount, payment_method,
    status, notes, client_name, received_amount, sale_type, created_at, updated_at
  ) VALUES (
    v_sale_id, v_company_id, p_warehouse_id, v_total, 0.0, 'cash',
    'pending', p_customer_note, v_table_name, 0.0, 'pos', NOW(), NOW()
  );

  -- 5. If table is ordered, update table status to occupied
  IF p_table_id IS NOT NULL THEN
    UPDATE kitchen_tables SET status = 'occupied', updated_at = NOW() WHERE id = p_table_id;
  END IF;

  -- 6. Insert items & modifiers
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_sale_item_id := gen_random_uuid();
    
    INSERT INTO sale_items (
      id, sale_id, product_id, product_name, quantity, selling_price, cost_price,
      discount_amount, item_type, created_at
    ) VALUES (
      v_sale_item_id,
      v_sale_id,
      (v_item->>'product_id')::UUID,
      (v_item->>'name')::TEXT,
      (v_item->>'quantity')::INT,
      (v_item->>'unit_price')::DECIMAL,
      0.0,
      0.0,
      'product',
      NOW()
    );

    -- Insert modifiers for this item
    IF v_item->'modifiers' IS NOT NULL AND jsonb_array_length(v_item->'modifiers') > 0 THEN
      FOR v_modifier IN SELECT * FROM jsonb_array_elements(v_item->'modifiers') LOOP
        INSERT INTO delivery_order_item_modifiers (
          id, order_item_id, modifier_id, modifier_name, group_name, price_delta, created_at
        ) VALUES (
          gen_random_uuid(),
          v_sale_item_id,
          (v_modifier->>'modifier_id')::UUID,
          (v_modifier->>'modifier_name')::TEXT,
          (v_modifier->>'group_name')::TEXT,
          (v_modifier->>'price_delta')::DECIMAL,
          NOW()
        );
      END LOOP;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'id', v_sale_id,
    'client_name', v_table_name,
    'total_amount', v_total
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_kitchen_customer_order TO authenticated;
GRANT EXECUTE ON FUNCTION create_kitchen_customer_order TO anon;
