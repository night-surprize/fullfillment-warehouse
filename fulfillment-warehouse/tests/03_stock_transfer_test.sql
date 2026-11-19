-- Финальный ROLLBACK удаляет все добавленные тестом данные.
-- Выполнять файл целиком, включая BEGIN и ROLLBACK.

BEGIN;

SET LOCAL search_path TO warehouse, public;

DO $$
DECLARE
    v_suffix TEXT := txid_current()::TEXT;
    v_seller BIGINT;
    v_category BIGINT;
    v_employee BIGINT;
    v_product BIGINT;
    v_root BIGINT;
    v_storage BIGINT;
    v_damaged BIGINT;
    v_source BIGINT;
    v_target BIGINT;
    v_damage_cell BIGINT;
    v_movements INTEGER;
BEGIN
    INSERT INTO sellers (seller_code, name)
        VALUES ('TEST-S-' || v_suffix, 'Transfer test seller')
    RETURNING
        seller_id
    INTO
        v_seller;
    INSERT INTO product_categories (name)
        VALUES ('Transfer test category ' || v_suffix)
    RETURNING
        category_id
    INTO
        v_category;
    INSERT INTO employees (employee_code, full_name)
        VALUES ('TEST-E-' || v_suffix, 'Transfer test employee')
    RETURNING
        employee_id
    INTO
        v_employee;
    INSERT INTO products (seller_id, category_id, sku, name, unit_weight_kg, unit_volume_m3)
        VALUES (v_seller, v_category, 'TEST-P-' || v_suffix, 'Transfer test product', 0.5, 0.01)
    RETURNING
        product_id
    INTO
        v_product;

    SELECT
        location_id
    INTO
        v_root
    FROM
        warehouse_locations
    WHERE
        location_kind = 'warehouse'
        AND deleted_at IS NULL;
    IF v_root IS NULL THEN
        INSERT INTO warehouse_locations (location_code, name, location_kind)
            VALUES ('TEST-W-' || v_suffix, 'Test warehouse', 'warehouse')
        RETURNING
            location_id
        INTO
            v_root;
    END IF;

    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (v_root, 'TEST-ZS-' || v_suffix, 'Storage', 'zone', 'storage')
    RETURNING
        location_id
    INTO
        v_storage;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (v_root, 'TEST-ZD-' || v_suffix, 'Damaged', 'zone', 'damaged')
    RETURNING
        location_id
    INTO
        v_damaged;

    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (v_storage, 'TEST-C1-' || v_suffix, 'Source', 'cell', 20, 1)
    RETURNING
        location_id
    INTO
        v_source;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (v_storage, 'TEST-C2-' || v_suffix, 'Target', 'cell', 1.5, 0.03)
    RETURNING
        location_id
    INTO
        v_target;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (v_damaged, 'TEST-CD-' || v_suffix, 'Damaged cell', 'cell', 20, 1)
    RETURNING
        location_id
    INTO
        v_damage_cell;

    INSERT INTO inventory (product_id, location_id, quantity)
        VALUES (v_product, v_source, 10);

    CALL transfer_stock (v_product, v_source, v_target, 3, v_employee);
    IF (
        SELECT
            quantity
        FROM
            inventory
        WHERE
            location_id = v_source) <> 7 OR (
    SELECT
        quantity
    FROM
        inventory
    WHERE
        location_id = v_target) <> 3 THEN
        RAISE EXCEPTION 'Balances after transfer are incorrect';
    END IF;

    BEGIN
        CALL transfer_stock (v_product, v_source, v_target, 1, v_employee);
        RAISE EXCEPTION 'Capacity violation was not rejected';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM <> 'Cell capacity exceeded' THEN
                RAISE;
                END IF;
    END;

    BEGIN
        CALL transfer_stock (v_product, v_source, v_damage_cell, 8, v_employee);
        RAISE EXCEPTION 'Insufficient stock was not rejected';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM <> 'Insufficient stock' THEN
                RAISE;
                END IF;
    END;

    CALL transfer_stock (v_product, v_source, v_damage_cell, 2, v_employee);
    IF (
        SELECT
            quantity
        FROM
            inventory
        WHERE
            location_id = v_source) <> 5 OR (
    SELECT
        quantity
    FROM
        inventory
    WHERE
        location_id = v_target) <> 3 OR (
SELECT
    quantity
FROM
    inventory
WHERE
    location_id = v_damage_cell) <> 2 THEN
        RAISE EXCEPTION 'Balances after damaged transfer are incorrect';
        END IF;

        SELECT
            COUNT(*)
        INTO
            v_movements
        FROM
            stock_movements
        WHERE
            product_id = v_product;
            IF v_movements <> 2 OR NOT EXISTS (
                SELECT
                    1
                FROM
                    stock_movements
                WHERE
                    product_id = v_product
                    AND movement_type = 'damage_transfer'
                    AND quantity = 2
                    AND to_location_id = v_damage_cell) THEN
                RAISE EXCEPTION 'Movement history is incorrect';
                END IF;

                RAISE NOTICE 'Stock transfer test passed';
END;

$$;

ROLLBACK;
