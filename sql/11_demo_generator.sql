-- Создает процедуру генерации. Для заполнения базы ее нужно вызвать отдельно.
BEGIN;

SET LOCAL search_path = warehouse, public;

CREATE PROCEDURE generate_demo_data (p_cycles INTEGER DEFAULT 5000, p_seed DOUBLE PRECISION DEFAULT 0.42)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    v_prefix TEXT := 'DEMO-' || txid_current();
    root_id BIGINT;
    storage_id BIGINT;
    packing_id BIGINT;
    damaged_id BIGINT;
    cat BIGINT;
    emp BIGINT;
    center_id BIGINT;
    seller BIGINT;
    prod BIGINT;
    src BIGINT;
    dst BIGINT;
    bad BIGINT;
    receipt BIGINT;
    item BIGINT;
    shipment BIGINT;
    ship_item BIGINT;
    j INTEGER;
    qty INTEGER;
    good INTEGER;
    seller_ids BIGINT[] := '{}';
    products_ids BIGINT[] := '{}';
    source_ids BIGINT[] := '{}';
    target_ids BIGINT[] := '{}';
    damage_ids BIGINT[] := '{}';
    idx INTEGER;
BEGIN
    IF p_cycles IS NULL OR p_cycles < 1 OR p_cycles > 100000 OR p_seed IS NULL OR p_seed NOT BETWEEN -1 AND 1 THEN
        RAISE EXCEPTION 'Cycles: 1..100000; seed: -1..1';
    END IF;
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    PERFORM
        setseed(p_seed);
    SELECT
        location_id
    INTO
        root_id
    FROM
        warehouse_locations
    WHERE
        location_kind = 'warehouse'
        AND deleted_at IS NULL;
    IF root_id IS NULL THEN
        INSERT INTO warehouse_locations (location_code, name, location_kind)
            VALUES (v_prefix, 'Demo warehouse', 'warehouse')
        RETURNING
            location_id
        INTO
            root_id;
    END IF;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root_id, v_prefix || '-S', 'Demo storage', 'zone', 'storage')
    RETURNING
        location_id
    INTO
        storage_id;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root_id, v_prefix || '-P', 'Demo packing', 'zone', 'packing')
    RETURNING
        location_id
    INTO
        packing_id;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root_id, v_prefix || '-D', 'Demo damaged', 'zone', 'damaged')
    RETURNING
        location_id
    INTO
        damaged_id;
    INSERT INTO product_categories (name)
        VALUES (v_prefix)
    RETURNING
        category_id
    INTO
        cat;
    INSERT INTO employees (employee_code, full_name)
        VALUES (v_prefix, 'Demo operator')
    RETURNING
        employee_id
    INTO
        emp;
    INSERT INTO sorting_centers (center_code, name, address)
        VALUES (v_prefix, 'Demo center', 'Demo address')
    RETURNING
        sorting_center_id
    INTO
        center_id;
    FOR j IN 1..20 LOOP
        INSERT INTO sellers (seller_code, name)
            VALUES (v_prefix || '-' || j, 'Demo seller ' || j)
        RETURNING
            seller_id
        INTO
            seller;
        seller_ids := array_append(seller_ids, seller);
    END LOOP;
    FOR j IN 1..200 LOOP
        INSERT INTO products (seller_id, category_id, sku, name, unit_weight_kg, unit_volume_m3)
        VALUES (seller_ids[1 + (j - 1) % 20], cat, v_prefix || '-SKU-' || j,
        'Demo product ' || j, 0.1 + random(), 0.001 + random() * 0.01)
        RETURNING
            product_id
        INTO
            prod;
        products_ids := array_append(products_ids, prod);
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
        max_weight_kg, max_volume_m3)
            VALUES (storage_id, v_prefix || '-S-' || j, 'Storage cell', 'cell', 10000000, 999999)
        RETURNING
            location_id
        INTO
            src;
        source_ids := array_append(source_ids, src);
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
        max_weight_kg, max_volume_m3)
            VALUES (packing_id, v_prefix || '-P-' || j, 'Packing cell', 'cell', 10000000, 999999)
        RETURNING
            location_id
        INTO
            dst;
        target_ids := array_append(target_ids, dst);
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
        max_weight_kg, max_volume_m3)
            VALUES (damaged_id, v_prefix || '-D-' || j, 'Damaged cell', 'cell', 10000000, 999999)
        RETURNING
            location_id
        INTO
            bad;
        damage_ids := array_append(damage_ids, bad);
    END LOOP;
    FOR j IN 1..p_cycles LOOP
        idx := 1 + floor(random() * 200)::INTEGER;
        prod := products_ids[idx];
        seller := seller_ids[1 + (idx - 1) % 20];
        src := source_ids[idx];
        dst := target_ids[idx];
        bad := damage_ids[idx];
        good := 80 + floor(random() * 21)::INTEGER;
        qty := 10 + floor(random() * 41)::INTEGER;
        INSERT INTO receipts (receipt_number, receipt_type, seller_id, created_by_employee_id, created_at)
        VALUES (v_prefix || '-R-' || j, 'supplier', seller, emp,
        CURRENT_TIMESTAMP - (floor(random() * 30)::INTEGER || ' days')::INTERVAL)
        RETURNING
            receipt_id
        INTO
            receipt;
        INSERT INTO receipt_items (receipt_id, product_id, expected_quantity)
            VALUES (receipt, prod, 100)
        RETURNING
            receipt_item_id
        INTO
            item;
        CALL start_receipt (receipt, emp);
        CALL receive_receipt (
            receipt,
            emp,
            jsonb_build_array(
                jsonb_build_object(
                    'item_id', item,
                    'accepted', good,
                    'damaged', 2,
                    'cell_id', src,
                    'damaged_cell_id', bad
                )
            )
        );
        INSERT INTO shipments (shipment_number, seller_id, sorting_center_id, created_by_employee_id, created_at)
        VALUES (v_prefix || '-O-' || j, seller, center_id, emp, CURRENT_TIMESTAMP -
        (floor(random() * 30)::INTEGER || ' days')::INTERVAL)
        RETURNING
            shipment_id
        INTO
            shipment;
        INSERT INTO shipment_items (shipment_id, product_id, requested_quantity)
            VALUES (shipment, prod, qty)
        RETURNING
            shipment_item_id
        INTO
            ship_item;
        CALL confirm_shipment (shipment);
        CALL pick_shipment (
            shipment,
            emp,
            jsonb_build_array(
                jsonb_build_object(
                    'item_id', ship_item,
                    'from_cell', src,
                    'to_cell', dst,
                    'quantity', qty
                )
            )
        );
        CALL pack_shipment (shipment);
        CALL dispatch_shipment (shipment, emp);
        IF j % 10 = 0 THEN
        INSERT INTO receipts (receipt_number, receipt_type, seller_id, sorting_center_id,
        source_shipment_id, created_by_employee_id)
                VALUES (v_prefix || '-RET-' || j, 'return', seller, center_id, shipment, emp)
            RETURNING
                receipt_id
            INTO
                receipt;
            INSERT INTO receipt_items (receipt_id, product_id, expected_quantity)
                VALUES (receipt, prod, 2)
            RETURNING
                receipt_item_id
            INTO
                item;
            CALL start_receipt (receipt, emp);
            CALL receive_receipt (
                receipt,
                emp,
                jsonb_build_array(
                    jsonb_build_object(
                        'item_id', item,
                        'accepted', 2,
                        'damaged', 0,
                        'cell_id', src
                    )
                )
            );
        END IF;
    END LOOP;
    RAISE NOTICE 'Generated % receipt/shipment cycles; prefix %', p_cycles, v_prefix;
END
$$;

COMMIT;
