BEGIN;

SET LOCAL search_path = warehouse, public;

CREATE FUNCTION cell_zone (p_cell BIGINT)
    RETURNS zone_purpose
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    v_zone zone_purpose;
    v_active BOOLEAN;
BEGIN
    IF NOT EXISTS (
        SELECT
        FROM
            warehouse_locations
        WHERE
            location_id = p_cell
            AND location_kind = 'cell') THEN
        RAISE EXCEPTION 'Location % is not a cell', p_cell;
    END IF;
    WITH RECURSIVE tree AS (
        SELECT
            location_id,
            parent_location_id,
            zone_purpose,
            deleted_at,
            ARRAY[location_id] AS path
        FROM
            warehouse_locations
        WHERE
            location_id = p_cell
        UNION ALL
        SELECT
            p.location_id,
            p.parent_location_id,
            p.zone_purpose,
            p.deleted_at,
            t.path || p.location_id
        FROM
            tree t
            JOIN warehouse_locations p ON p.location_id = t.parent_location_id
        WHERE
            NOT p.location_id = ANY (t.path)
    )
    SELECT
        MAX(zone_purpose::TEXT)::zone_purpose,
        BOOL_AND(deleted_at IS NULL)
    INTO
        v_zone,
        v_active
    FROM
        tree;
    IF v_zone IS NULL OR NOT v_active THEN
        RAISE EXCEPTION 'Cell % has no active zone', p_cell;
    END IF;
    RETURN v_zone;
END
$$;

-- Общая блокировка выстраивает все операции с остатками в одну очередь.
CREATE FUNCTION post_stock (p_kind movement_type, p_product BIGINT, p_qty INTEGER, p_from BIGINT,
    p_to BIGINT, p_employee BIGINT, p_receipt BIGINT DEFAULT NULL, p_shipment BIGINT DEFAULT NULL,
    p_pick BIGINT DEFAULT NULL)
    RETURNS VOID
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    v_product products%ROWTYPE;
    v_qty INTEGER;
    v_other BIGINT;
    v_limit warehouse_locations%ROWTYPE;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    IF p_qty IS NULL OR p_qty <= 0 OR p_from = p_to OR (p_from IS NULL AND p_to IS NULL) THEN
        RAISE EXCEPTION 'Invalid stock movement';
    END IF;
    SELECT
        *
    INTO
        STRICT v_product
    FROM
        products
    WHERE
        product_id = p_product
        AND deleted_at IS NULL;
    PERFORM
        1
    FROM
        employees
    WHERE
        employee_id = p_employee
        AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active employee required';
    END IF;
    IF p_from IS NOT NULL THEN
        PERFORM
            cell_zone (p_from);
        SELECT
            quantity
        INTO
            v_qty
        FROM
            inventory
        WHERE
            location_id = p_from
            AND product_id = p_product
        FOR UPDATE;
        IF v_qty IS NULL OR v_qty < p_qty THEN
            RAISE EXCEPTION 'Insufficient stock';
        END IF;
    END IF;
    IF p_to IS NOT NULL THEN
        PERFORM
            cell_zone (p_to);
        SELECT
            *
        INTO
            STRICT v_limit
        FROM
            warehouse_locations
        WHERE
            location_id = p_to
        FOR UPDATE;
        SELECT
            product_id,
            quantity
        INTO
            v_other,
            v_qty
        FROM
            inventory
        WHERE
            location_id = p_to
        FOR UPDATE;
        IF v_other IS NOT NULL AND v_other <> p_product THEN
            RAISE EXCEPTION 'Cell contains a different product';
        END IF;
    IF (COALESCE(v_qty, 0)::NUMERIC + p_qty) * v_product.unit_weight_kg > v_limit.max_weight_kg
        OR (COALESCE(v_qty, 0)::NUMERIC + p_qty) * v_product.unit_volume_m3 >
        v_limit.max_volume_m3 THEN
            RAISE EXCEPTION 'Cell capacity exceeded';
        END IF;
    END IF;
    IF p_from IS NOT NULL THEN
        DELETE FROM inventory
        WHERE location_id = p_from
            AND quantity = p_qty;
        IF NOT FOUND THEN
            UPDATE
                inventory
            SET
                quantity = quantity - p_qty,
                updated_at = CURRENT_TIMESTAMP
            WHERE
                location_id = p_from;
        END IF;
    END IF;
    IF p_to IS NOT NULL THEN
        INSERT INTO inventory (product_id, location_id, quantity)
            VALUES (p_product, p_to, p_qty)
        ON CONFLICT (location_id)
            DO UPDATE SET
                quantity = inventory.quantity + EXCLUDED.quantity,
                updated_at = CURRENT_TIMESTAMP;
    END IF;
    INSERT INTO stock_movements (movement_type, product_id, quantity, from_location_id,
    to_location_id, performed_by_employee_id, receipt_item_id, shipment_item_id,
    picking_task_id)
        VALUES (p_kind, p_product, p_qty, p_from, p_to, p_employee, p_receipt, p_shipment, p_pick);
END
$$;

-- Заменяет прежнее перемещение вызовом общей функции проведения.
CREATE OR REPLACE PROCEDURE transfer_stock (p_product_id BIGINT, p_from_location_id BIGINT,
    p_to_location_id BIGINT, p_quantity INTEGER, p_employee_id BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    v_kind movement_type;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    IF p_from_location_id IS NULL OR p_to_location_id IS NULL THEN
        RAISE EXCEPTION 'Two cells required';
    END IF;
    IF cell_zone (p_from_location_id) = 'damaged' THEN
        RAISE EXCEPTION 'Cannot move stock out of damaged zone';
    END IF;
    v_kind := CASE WHEN cell_zone (p_to_location_id) = 'damaged' THEN
        'damage_transfer'::movement_type
    ELSE
        'transfer'::movement_type
    END;
    PERFORM
        post_stock (v_kind, p_product_id, p_quantity, p_from_location_id, p_to_location_id, p_employee_id);
END
$$;

CREATE PROCEDURE start_receipt (p_receipt BIGINT, p_employee BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    PERFORM
        1
    FROM
        employees
    WHERE
        employee_id = p_employee
        AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active employee required';
    END IF;
    UPDATE
        receipts
    SET
        status = 'receiving',
        processed_by_employee_id = p_employee,
        started_at = CURRENT_TIMESTAMP
    WHERE
        receipt_id = p_receipt
        AND status IN ('created', 'expected');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receipt cannot be started';
    END IF;
END
$$;

-- Приемка проводится целиком: для каждой позиции задаются ячейки годного товара и брака.
CREATE PROCEDURE receive_receipt (p_receipt BIGINT, p_employee BIGINT, p_lines JSONB)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    r receipts%ROWTYPE;
    i receipt_items%ROWTYPE;
    x RECORD;
    n INTEGER := 0;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    SELECT
        *
    INTO
        STRICT r
    FROM
        receipts
    WHERE
        receipt_id = p_receipt
    FOR UPDATE;
    PERFORM
        1
    FROM
        employees
    WHERE
        employee_id = p_employee
        AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active employee required';
    END IF;
    IF r.status <> 'receiving' OR jsonb_typeof(p_lines) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Receiving receipt and array required';
    END IF;
    IF (
        SELECT
            COUNT(*)
        FROM
            jsonb_array_elements(p_lines)) <> (
    SELECT
        COUNT(DISTINCT (a ->> 'item_id')::BIGINT)
    FROM
        jsonb_array_elements(p_lines) a) THEN
        RAISE EXCEPTION 'Duplicate receipt line';
    END IF;
    FOR x IN
    SELECT
        *
    FROM
        jsonb_to_recordset(p_lines) AS t (item_id BIGINT,
        accepted INTEGER,
        damaged INTEGER,
        cell_id BIGINT,
        damaged_cell_id BIGINT)
    LOOP
        SELECT
            *
        INTO
            STRICT i
        FROM
            receipt_items
        WHERE
            receipt_item_id = x.item_id
            AND receipt_id = p_receipt;
        IF x.accepted IS NULL OR x.damaged IS NULL OR x.accepted < 0 OR x.damaged < 0 THEN
            RAISE EXCEPTION 'Nonnegative line quantities required';
        END IF;
        IF x.accepted > 0 THEN
            IF cell_zone (x.cell_id)
                NOT IN ('receiving', 'storage') THEN
                RAISE EXCEPTION 'Receiving or storage cell required';
            END IF;
            PERFORM
                post_stock (
                    CASE WHEN r.receipt_type = 'return' THEN
                        'return_receipt'::movement_type
                    ELSE
                        'receipt'::movement_type
                    END, i.product_id, x.accepted, NULL, x.cell_id, p_employee, i.receipt_item_id);
        END IF;
        IF x.damaged > 0 THEN
            IF cell_zone (x.damaged_cell_id) <> 'damaged' THEN
                RAISE EXCEPTION 'Damaged cell required';
            END IF;
            PERFORM
                post_stock (
                    CASE WHEN r.receipt_type = 'return' THEN
                        'return_receipt'::movement_type
                    ELSE
                        'receipt'::movement_type
                    END, i.product_id, x.damaged, NULL, x.damaged_cell_id, p_employee, i.receipt_item_id);
        END IF;
        UPDATE
            receipt_items
        SET
            received_quantity = x.accepted + x.damaged,
            accepted_quantity = x.accepted,
            damaged_quantity = x.damaged
        WHERE
            receipt_item_id = i.receipt_item_id;
        n := n + 1;
    END LOOP;
    IF n = 0 OR n <> (
        SELECT
            COUNT(*)
        FROM
            receipt_items
        WHERE
            receipt_id = p_receipt) THEN
        RAISE EXCEPTION 'Provide every receipt line exactly once';
    END IF;
    UPDATE
        receipts
    SET
        status = 'received',
        completed_at = CURRENT_TIMESTAMP,
        processed_by_employee_id = p_employee
    WHERE
        receipt_id = p_receipt;
END
$$;

CREATE PROCEDURE confirm_shipment (p_shipment BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    IF NOT EXISTS (
        SELECT
        FROM
            shipment_items
        WHERE
            shipment_id = p_shipment) THEN
        RAISE EXCEPTION 'Empty shipment';
    END IF;
    UPDATE
        shipments
    SET
        status = 'confirmed',
        confirmed_at = CURRENT_TIMESTAMP
    WHERE
        shipment_id = p_shipment
        AND status = 'created';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment cannot be confirmed';
    END IF;
END
$$;

-- Сборка сразу перемещает товар. При нехватке остатка весь вызов откатывается.
CREATE PROCEDURE pick_shipment (p_shipment BIGINT, p_employee BIGINT, p_lines JSONB)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    x RECORD;
    i shipment_items%ROWTYPE;
    v_task BIGINT;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    PERFORM
        1
    FROM
        shipments
    WHERE
        shipment_id = p_shipment
        AND status = 'confirmed'
    FOR UPDATE;
    IF NOT FOUND OR jsonb_typeof(p_lines) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Confirmed shipment and array required';
    END IF;
    FOR x IN
    SELECT
        *
    FROM
        jsonb_to_recordset(p_lines) AS t (item_id BIGINT,
        from_cell BIGINT,
        to_cell BIGINT,
        quantity INTEGER)
    LOOP
        SELECT
            *
        INTO
            STRICT i
        FROM
            shipment_items
        WHERE
            shipment_item_id = x.item_id
            AND shipment_id = p_shipment;
        IF cell_zone (x.from_cell) <> 'storage' OR cell_zone (x.to_cell) <> 'packing' THEN
            RAISE EXCEPTION 'Picking requires storage to packing route';
        END IF;
    INSERT INTO picking_tasks (shipment_item_id, source_location_id, target_location_id,
        assigned_employee_id, requested_quantity)
            VALUES (i.shipment_item_id, x.from_cell, x.to_cell, p_employee, x.quantity)
        RETURNING
            picking_task_id
        INTO
            v_task;
        UPDATE
            picking_tasks
        SET
            status = 'in_progress',
            started_at = CURRENT_TIMESTAMP
        WHERE
            picking_task_id = v_task;
        PERFORM
        post_stock ('picking', i.product_id, x.quantity, x.from_cell, x.to_cell,
        p_employee, NULL, NULL, v_task);
        UPDATE
            picking_tasks
        SET
            status = 'completed',
            picked_quantity = x.quantity,
            completed_at = CURRENT_TIMESTAMP
        WHERE
            picking_task_id = v_task;
    END LOOP;
    IF NOT EXISTS (
        SELECT
        FROM
            picking_tasks t
            JOIN shipment_items line USING (shipment_item_id)
        WHERE
            line.shipment_id = p_shipment) OR EXISTS (
    SELECT
    FROM
        shipment_items line
    WHERE
        line.shipment_id = p_shipment
            AND line.requested_quantity < (
            SELECT
                COALESCE(SUM(picked_quantity), 0)
            FROM
                picking_tasks t
            WHERE
                t.shipment_item_id = line.shipment_item_id
                AND status = 'completed')) THEN
        RAISE EXCEPTION 'Pick a positive quantity without exceeding requested quantities';
    END IF;
    UPDATE
        shipments
    SET
        status = 'picked',
        picked_at = CURRENT_TIMESTAMP
    WHERE
        shipment_id = p_shipment;
END
$$;

CREATE PROCEDURE pack_shipment (p_shipment BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    UPDATE
        shipments
    SET
        status = 'packed',
        packed_at = CURRENT_TIMESTAMP
    WHERE
        shipment_id = p_shipment
        AND status = 'picked';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment cannot be packed';
    END IF;
END
$$;

CREATE PROCEDURE dispatch_shipment (p_shipment BIGINT, p_employee BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    x RECORD;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    PERFORM
        1
    FROM
        shipments
    WHERE
        shipment_id = p_shipment
        AND status = 'packed'
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Packed shipment required';
    END IF;
    FOR x IN
    SELECT
        t.*,
        i.product_id
    FROM
        picking_tasks t
        JOIN shipment_items i USING (shipment_item_id)
    WHERE
        i.shipment_id = p_shipment
        AND t.status = 'completed'
    ORDER BY
        t.picking_task_id LOOP
            PERFORM
        post_stock ('shipment', x.product_id, x.picked_quantity, x.target_location_id,
            NULL, p_employee, NULL, x.shipment_item_id);
        END LOOP;
    UPDATE
        shipment_items line
    SET
        shipped_quantity = (
            SELECT
                COALESCE(SUM(picked_quantity), 0)
            FROM
                picking_tasks
            WHERE
                shipment_item_id = line.shipment_item_id
                AND status = 'completed')
    WHERE
        shipment_id = p_shipment;
    UPDATE
        shipments
    SET
        status = 'shipped',
        shipped_at = CURRENT_TIMESTAMP
    WHERE
        shipment_id = p_shipment;
END
$$;

COMMIT;
