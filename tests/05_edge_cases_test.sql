-- Нужны сгенерированные данные. Все добавленные документы откатываются.
BEGIN;

SET LOCAL search_path = warehouse, public;

DO $$
DECLARE
    prod BIGINT;
    seller BIGINT;
    emp BIGINT;
    center_id BIGINT;
    src BIGINT;
    dst BIGINT;
    receipt BIGINT;
    item BIGINT;
    shipment BIGINT;
    ship_item BIGINT;
    before_qty INTEGER;
    before_moves BIGINT;
    prefix TEXT := 'EDGE-' || txid_current();
BEGIN
    SELECT
        i.product_id,
        p.seller_id,
        i.location_id,
        i.quantity
    INTO
        prod,
        seller,
        src,
        before_qty
    FROM
        inventory i
        JOIN products p USING (product_id)
    WHERE
        cell_zone (i.location_id) = 'storage'
        AND i.quantity > 10
    LIMIT 1;
    SELECT
        MIN(employee_id)
    INTO
        emp
    FROM
        employees;
    SELECT
        MIN(sorting_center_id)
    INTO
        center_id
    FROM
        sorting_centers;
    SELECT
        t.target_location_id
    INTO
        dst
    FROM
        picking_tasks t
        JOIN shipment_items i USING (shipment_item_id)
    WHERE
        i.product_id = prod
    LIMIT 1;
    IF prod IS NULL OR dst IS NULL THEN
        RAISE EXCEPTION 'Demo fixtures missing';
    END IF;
    INSERT INTO receipts (receipt_number, receipt_type, seller_id, created_by_employee_id)
        VALUES (prefix, 'supplier', seller, emp)
    RETURNING
        receipt_id
    INTO
        receipt;
    INSERT INTO receipt_items (receipt_id, product_id, expected_quantity)
        VALUES (receipt, prod, 5)
    RETURNING
        receipt_item_id
    INTO
        item;
    BEGIN
        UPDATE
            receipts
        SET
            status = 'received'
        WHERE
            receipt_id = receipt;
        RAISE EXCEPTION
            USING ERRCODE = 'ZX001', MESSAGE = 'Invalid transition accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'ZX001' OR SQLERRM NOT LIKE 'Invalid receipt transition:%' THEN
                RAISE;
                END IF;
    END;
    CALL start_receipt (receipt, emp);
    SELECT
        COUNT(*)
    INTO
        before_moves
    FROM
        stock_movements;
        BEGIN
            CALL receive_receipt (
                receipt,
                emp,
                jsonb_build_array(
                    jsonb_build_object(
                        'item_id', item,
                        'accepted', 1,
                        'damaged', 1,
                        'cell_id', src,
                        'damaged_cell_id', dst
                    )
                )
            );
            RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Invalid damaged cell accepted';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLSTATE = 'ZX001' OR SQLERRM <> 'Damaged cell required' THEN
                    RAISE;
                    END IF;
        END;
        IF (
            SELECT
                quantity
            FROM
                inventory
            WHERE
                location_id = src) <> before_qty OR (
        SELECT
            COUNT(*)
        FROM
            stock_movements) <> before_moves THEN
            RAISE EXCEPTION 'Failed receipt was not fully rolled back';
            END IF;
            CALL receive_receipt (
                receipt,
                emp,
                jsonb_build_array(
                    jsonb_build_object(
                        'item_id', item,
                        'accepted', 5,
                        'damaged', 0,
                        'cell_id', src
                    )
                )
            );
            BEGIN
                CALL receive_receipt (receipt, emp, '[]');
                RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Repeated receipt accepted';
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLSTATE = 'ZX001' OR SQLERRM <> 'Receiving receipt and array required' THEN
                        RAISE;
                        END IF;
            END;

        INSERT INTO shipments (shipment_number, seller_id, sorting_center_id, created_by_employee_id)
            VALUES (prefix, seller, center_id, emp)
        RETURNING
            shipment_id
        INTO
            shipment;
        INSERT INTO shipment_items (shipment_id, product_id, requested_quantity)
            VALUES (shipment, prod, 5)
        RETURNING
            shipment_item_id
        INTO
            ship_item;
            CALL confirm_shipment (shipment);
            BEGIN
                CALL pick_shipment (
                    shipment,
                    emp,
                    jsonb_build_array(
                        jsonb_build_object(
                            'item_id', ship_item,
                            'from_cell', src,
                            'to_cell', dst,
                            'quantity', 6
                        )
                    )
                );
                RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Excess picking accepted';
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLSTATE = 'ZX001' OR SQLERRM <> 'Pick a positive quantity without exceeding requested quantities' THEN
                        RAISE;
                        END IF;
            END;
            IF EXISTS (
                SELECT
                FROM
                    picking_tasks
                WHERE
                    shipment_item_id = ship_item) THEN
                RAISE EXCEPTION 'Failed picking left tasks behind';
                END IF;
                CALL pick_shipment (
                    shipment,
                    emp,
                    jsonb_build_array(
                        jsonb_build_object(
                            'item_id', ship_item,
                            'from_cell', src,
                            'to_cell', dst,
                            'quantity', 2
                        )
                    )
                );
                CALL pack_shipment (shipment);
                CALL dispatch_shipment (shipment, emp);
                IF (
                    SELECT
                        shipped_quantity
                    FROM
                        shipment_items
                    WHERE
                        shipment_item_id = ship_item) <> 2 THEN
                    RAISE EXCEPTION 'Partial shipment incorrect';
                    END IF;
                    IF EXISTS (
                        SELECT
                        FROM
                            v_inventory_reconciliation) THEN
                        RAISE EXCEPTION 'Ledger mismatch';
                        END IF;
                        RAISE NOTICE 'Edge cases passed';
END
$$;

ROLLBACK;
