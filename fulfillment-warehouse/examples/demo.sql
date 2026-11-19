-- Выполнять целиком в новом подключении. Финальный ROLLBACK удаляет данные примера.
BEGIN;

SET LOCAL search_path = warehouse, public;

CREATE TEMP TABLE demo_ids (
    product_id BIGINT,
    receipt_id BIGINT,
    shipment_id BIGINT
) ON COMMIT DROP;

DO $$
DECLARE
    prefix TEXT := 'WALK-' || txid_current();
    seller BIGINT;
    category BIGINT;
    employee BIGINT;
    center BIGINT;
    product BIGINT;
    root BIGINT;
    storage_zone BIGINT;
    packing_zone BIGINT;
    damaged_zone BIGINT;
    storage_cell BIGINT;
    overflow_cell BIGINT;
    packing_cell BIGINT;
    damaged_cell BIGINT;
    receipt BIGINT;
    receipt_item BIGINT;
    shipment BIGINT;
    shipment_item BIGINT;
BEGIN
    INSERT INTO sellers (seller_code, name)
        VALUES (prefix, 'Demo seller')
    RETURNING
        seller_id
    INTO
        seller;
    INSERT INTO product_categories (name)
        VALUES (prefix)
    RETURNING
        category_id
    INTO
        category;
    INSERT INTO employees (employee_code, full_name)
        VALUES (prefix, 'Demo operator')
    RETURNING
        employee_id
    INTO
        employee;
    INSERT INTO sorting_centers (center_code, name, address)
        VALUES (prefix, 'Demo sorting center', 'Demo address')
    RETURNING
        sorting_center_id
    INTO
        center;
    INSERT INTO products (seller_id, category_id, sku, name, unit_weight_kg, unit_volume_m3)
        VALUES (seller, category, prefix, 'Desk lamp', 0.5, 0.01)
    RETURNING
        product_id
    INTO
        product;

    SELECT
        location_id
    INTO
        root
    FROM
        warehouse_locations
    WHERE
        location_kind = 'warehouse'
        AND deleted_at IS NULL;
    IF root IS NULL THEN
        INSERT INTO warehouse_locations (location_code, name, location_kind)
            VALUES (prefix, 'Demo warehouse', 'warehouse')
        RETURNING
            location_id
        INTO
            root;
    END IF;

    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root, prefix || '-S', 'Storage', 'zone', 'storage')
    RETURNING
        location_id
    INTO
        storage_zone;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root, prefix || '-P', 'Packing', 'zone', 'packing')
    RETURNING
        location_id
    INTO
        packing_zone;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind, zone_purpose)
        VALUES (root, prefix || '-D', 'Damaged', 'zone', 'damaged')
    RETURNING
        location_id
    INTO
        damaged_zone;

    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (storage_zone, prefix || '-S1', 'Main cell', 'cell', 100, 2)
    RETURNING
        location_id
    INTO
        storage_cell;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (storage_zone, prefix || '-S2', 'Overflow cell', 'cell', 100, 2)
    RETURNING
        location_id
    INTO
        overflow_cell;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (packing_zone, prefix || '-P1', 'Packing cell', 'cell', 100, 2)
    RETURNING
        location_id
    INTO
        packing_cell;
    INSERT INTO warehouse_locations (parent_location_id, location_code, name, location_kind,
    max_weight_kg, max_volume_m3)
        VALUES (damaged_zone, prefix || '-D1', 'Damaged cell', 'cell', 100, 2)
    RETURNING
        location_id
    INTO
        damaged_cell;

    INSERT INTO receipts (receipt_number, receipt_type, seller_id, created_by_employee_id)
        VALUES (prefix, 'supplier', seller, employee)
    RETURNING
        receipt_id
    INTO
        receipt;
    INSERT INTO receipt_items (receipt_id, product_id, expected_quantity)
        VALUES (receipt, product, 100)
    RETURNING
        receipt_item_id
    INTO
        receipt_item;

    CALL start_receipt (receipt, employee);
    CALL receive_receipt (
        receipt,
        employee,
        jsonb_build_array(
            jsonb_build_object(
                'item_id', receipt_item,
                'accepted', 98,
                'damaged', 2,
                'cell_id', storage_cell,
                'damaged_cell_id', damaged_cell
            )
        )
    );
    CALL transfer_stock (product, storage_cell, overflow_cell, 10, employee);

    INSERT INTO shipments (shipment_number, seller_id, sorting_center_id, created_by_employee_id)
        VALUES (prefix, seller, center, employee)
    RETURNING
        shipment_id
    INTO
        shipment;
    INSERT INTO shipment_items (shipment_id, product_id, requested_quantity)
        VALUES (shipment, product, 8)
    RETURNING
        shipment_item_id
    INTO
        shipment_item;

    CALL confirm_shipment (shipment);
    CALL pick_shipment (
        shipment,
        employee,
        jsonb_build_array(
            jsonb_build_object(
                'item_id', shipment_item,
                'from_cell', storage_cell,
                'to_cell', packing_cell,
                'quantity', 5
            )
        )
    );
    CALL pack_shipment (shipment);
    CALL dispatch_shipment (shipment, employee);

    IF (
        SELECT
            SUM(quantity)
        FROM
            inventory
        WHERE
            product_id = product) <> 95 OR (
    SELECT
        shipped_quantity
    FROM
        shipment_items
    WHERE
        shipment_item_id = shipment_item) <> 5 OR EXISTS (
SELECT
FROM
    v_inventory_reconciliation
WHERE
    product_id = product) THEN
        RAISE EXCEPTION 'Demo balance check failed';
    END IF;
    INSERT INTO demo_ids
        VALUES (product, receipt, shipment);
END;
$$;

SELECT
    v.location_code,
    v.zone,
    v.quantity,
    v.weight_kg,
    v.volume_m3
FROM
    v_inventory v
    JOIN demo_ids d USING (product_id)
ORDER BY
    v.zone,
    v.location_code;

SELECT
    i.requested_quantity,
    i.shipped_quantity,
    s.status
FROM
    shipment_items i
    JOIN shipments s USING (shipment_id)
    JOIN demo_ids d USING (shipment_id);

SELECT
    m.movement_type,
    m.quantity,
    m.from_location_id,
    m.to_location_id
FROM
    stock_movements m
    JOIN demo_ids d USING (product_id)
ORDER BY
    m.movement_id;

ROLLBACK;
