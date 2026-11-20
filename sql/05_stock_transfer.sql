-- Миграция 05: перемещение товара между двумя ячейками в одной транзакции.

BEGIN;

CREATE OR REPLACE PROCEDURE warehouse.transfer_stock (p_product_id BIGINT, p_from_location_id
    BIGINT, p_to_location_id BIGINT, p_quantity INTEGER, p_employee_id BIGINT)
LANGUAGE plpgsql
SET search_path = warehouse, public
AS $$
DECLARE
    v_product products%ROWTYPE;
    v_source inventory%ROWTYPE;
    v_destination inventory%ROWTYPE;
    v_from_zone zone_purpose;
    v_to_zone zone_purpose;
    v_from_active BOOLEAN;
    v_to_active BOOLEAN;
    v_to_weight NUMERIC;
    v_to_volume NUMERIC;
    v_location_id BIGINT;
BEGIN
    IF p_product_id IS NULL OR p_from_location_id IS NULL OR p_to_location_id IS NULL OR
    p_employee_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0 OR p_from_location_id =
    p_to_location_id THEN
        RAISE EXCEPTION 'Provide a product, two different cells, a positive quantity and an employee';
    END IF;

    -- Одинаковый порядок блокировки ячеек снижает риск взаимных блокировок.
    FOR v_location_id IN
    SELECT
        location_id
    FROM
        warehouse_locations
    WHERE
        location_id IN (p_from_location_id, p_to_location_id)
    ORDER BY
        location_id
    FOR UPDATE LOOP
        NULL;
    END LOOP;

    SELECT
        *
    INTO
        v_product
    FROM
        products
    WHERE
        product_id = p_product_id
        AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active product % not found', p_product_id;
    END IF;

    PERFORM
        1
    FROM
        employees
    WHERE
        employee_id = p_employee_id
        AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active employee % not found', p_employee_id;
    END IF;

    -- Поднимаемся от ячеек к зонам; ограничение глубины защищает от ошибочной иерархии.
    WITH RECURSIVE ancestors AS (
        SELECT
            location_id,
            parent_location_id,
            location_kind,
            zone_purpose,
            deleted_at,
            location_id AS origin_id,
            0 AS depth
        FROM
            warehouse_locations
        WHERE
            location_id IN (p_from_location_id, p_to_location_id)
        UNION ALL
        SELECT
            parent.location_id,
            parent.parent_location_id,
            parent.location_kind,
            parent.zone_purpose,
            parent.deleted_at,
            child.origin_id,
            child.depth + 1
        FROM
            ancestors child
            JOIN warehouse_locations parent ON parent.location_id = child.parent_location_id
        WHERE
            child.depth < 32
    )
    SELECT
        MAX(zone_purpose::TEXT) FILTER (WHERE origin_id = p_from_location_id
            AND location_kind = 'zone')::zone_purpose,
        MAX(zone_purpose::TEXT) FILTER (WHERE origin_id = p_to_location_id
            AND location_kind = 'zone')::zone_purpose,
        BOOL_AND(deleted_at IS NULL) FILTER (WHERE origin_id = p_from_location_id),
        BOOL_AND(deleted_at IS NULL) FILTER (WHERE origin_id = p_to_location_id)
    INTO
        v_from_zone,
        v_to_zone,
        v_from_active,
        v_to_active
    FROM
        ancestors;

    IF (
        SELECT
            location_kind
        FROM
            warehouse_locations
        WHERE
            location_id = p_from_location_id) IS DISTINCT FROM 'cell' OR (
    SELECT
        location_kind
    FROM
        warehouse_locations
    WHERE
    location_id = p_to_location_id) IS DISTINCT FROM 'cell' OR v_from_zone IS NULL OR
        v_to_zone IS NULL OR v_from_active IS DISTINCT FROM TRUE OR v_to_active IS DISTINCT
        FROM TRUE THEN
        RAISE EXCEPTION 'Both locations must be active cells beneath an active zone';
    END IF;

    IF v_from_zone = 'damaged' THEN
        RAISE EXCEPTION 'Stock cannot be moved out of a damaged zone';
    END IF;

    SELECT
        *
    INTO
        v_source
    FROM
        inventory
    WHERE
        location_id = p_from_location_id
        AND product_id = p_product_id;

    IF NOT FOUND OR v_source.quantity < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock in cell % for product %', p_from_location_id, p_product_id;
    END IF;

    SELECT
        *
    INTO
        v_destination
    FROM
        inventory
    WHERE
        location_id = p_to_location_id;

    IF FOUND AND v_destination.product_id <> p_product_id THEN
        RAISE EXCEPTION 'Destination cell % contains a different product', p_to_location_id;
    END IF;

    SELECT
        max_weight_kg,
        max_volume_m3
    INTO
        v_to_weight,
        v_to_volume
    FROM
        warehouse_locations
    WHERE
        location_id = p_to_location_id;

    IF (COALESCE(v_destination.quantity, 0)::NUMERIC + p_quantity) * v_product.unit_weight_kg >
    v_to_weight OR (COALESCE(v_destination.quantity, 0)::NUMERIC + p_quantity) *
    v_product.unit_volume_m3 > v_to_volume THEN
        RAISE EXCEPTION 'Destination cell % exceeds weight or volume capacity', p_to_location_id;
    END IF;

    IF v_source.quantity = p_quantity THEN
        DELETE FROM inventory
        WHERE product_id = p_product_id
            AND location_id = p_from_location_id;
    ELSE
        UPDATE
            inventory
        SET
            quantity = quantity - p_quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE
            product_id = p_product_id
            AND location_id = p_from_location_id;
    END IF;

    INSERT INTO inventory (product_id, location_id, quantity)
        VALUES (p_product_id, p_to_location_id, p_quantity)
    ON CONFLICT (location_id)
        DO UPDATE SET
            quantity = inventory.quantity + EXCLUDED.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE
            inventory.product_id = EXCLUDED.product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination cell % contains a different product', p_to_location_id;
    END IF;

    INSERT INTO stock_movements (movement_type, product_id, quantity, from_location_id,
    to_location_id, performed_by_employee_id)
        VALUES (
            CASE WHEN v_to_zone = 'damaged' THEN
                'damage_transfer'::movement_type
            ELSE
                'transfer'::movement_type
            END, p_product_id, p_quantity, p_from_location_id, p_to_location_id, p_employee_id);
END;
$$;

COMMIT;
