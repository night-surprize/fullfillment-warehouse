BEGIN;

SET LOCAL search_path = warehouse, public;

CREATE FUNCTION document_guard ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    a TEXT;
    b TEXT;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    IF TG_OP = 'INSERT' THEN
        IF NEW.status::TEXT <> 'created' THEN
            RAISE EXCEPTION 'Documents must start in created status';
        END IF;
        IF TG_TABLE_NAME = 'receipts' THEN
            IF NEW.source_shipment_id IS NOT NULL THEN
                IF NOT EXISTS (
                    SELECT
                    FROM
                        shipments
                    WHERE
                        shipment_id = NEW.source_shipment_id
                        AND seller_id = NEW.seller_id
                        AND sorting_center_id = NEW.sorting_center_id
                        AND status = 'shipped') THEN
                    RAISE EXCEPTION 'Return source must be a shipped document of the same seller and center';
                END IF;
            END IF;
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Cancel documents instead of deleting them';
    END IF;
    a := OLD.status::TEXT;
    b := NEW.status::TEXT;
    IF a IN ('received', 'shipped', 'cancelled', 'completed') THEN
        RAISE EXCEPTION 'Final document is immutable';
    END IF;
    IF TG_TABLE_NAME = 'receipts' THEN
    IF NEW.seller_id <> OLD.seller_id OR NEW.receipt_type <> OLD.receipt_type OR
        NEW.source_shipment_id IS DISTINCT FROM OLD.source_shipment_id OR NEW.sorting_center_id
        IS DISTINCT FROM OLD.sorting_center_id THEN
            RAISE EXCEPTION 'Receipt identity is immutable';
        END IF;
    IF a <> b AND NOT ((a = 'created' AND b IN ('expected', 'receiving',
        'cancelled')) OR (a = 'expected' AND b IN ('receiving', 'cancelled'))
        OR (a = 'receiving' AND b IN ('received', 'cancelled'))) THEN
            RAISE EXCEPTION 'Invalid receipt transition: % -> %', a, b;
        END IF;
        IF b = 'cancelled' AND EXISTS (
            SELECT
            FROM
                stock_movements m
                JOIN receipt_items i USING (receipt_item_id)
            WHERE
                i.receipt_id = OLD.receipt_id) THEN
            RAISE EXCEPTION 'Posted receipt cannot be cancelled';
        END IF;
        IF b = 'received' THEN
            IF NOT EXISTS (
                SELECT
                FROM
                    receipt_items
                WHERE
                    receipt_id = OLD.receipt_id) OR EXISTS (
            SELECT
            FROM
                receipt_items i
            WHERE
                i.receipt_id = OLD.receipt_id
                    AND (i.received_quantity <> i.accepted_quantity + i.damaged_quantity
                    OR i.received_quantity <> (
                    SELECT
                        COALESCE(SUM(quantity), 0)
                    FROM
                        stock_movements
                    WHERE
                        receipt_item_id = i.receipt_item_id))) THEN
                RAISE EXCEPTION 'Receipt quantities and movements must reconcile';
            END IF;
            IF NEW.completed_at IS NULL OR NEW.started_at IS NULL THEN
                RAISE EXCEPTION 'Receipt timestamps required';
            END IF;
        END IF;
    ELSE
        IF NEW.seller_id <> OLD.seller_id OR NEW.sorting_center_id <> OLD.sorting_center_id THEN
            RAISE EXCEPTION 'Shipment identity is immutable';
        END IF;
    IF a <> b AND NOT ((a = 'created' AND b IN ('confirmed', 'cancelled')) OR (a
        = 'confirmed' AND b IN ('picked', 'cancelled')) OR (a = 'picked'
        AND b = 'packed') OR (a = 'packed' AND b = 'shipped')) THEN
            RAISE EXCEPTION 'Invalid shipment transition: % -> %', a, b;
        END IF;
        IF b = 'cancelled' AND EXISTS (
            SELECT
            FROM
                picking_tasks t
                JOIN shipment_items i USING (shipment_item_id)
            WHERE
                i.shipment_id = OLD.shipment_id
                AND t.picked_quantity > 0) THEN
            RAISE EXCEPTION 'Picked shipment cannot be cancelled';
        END IF;
        IF b IN ('confirmed', 'picked', 'packed', 'shipped') AND NOT EXISTS (
            SELECT
            FROM
                shipment_items
            WHERE
                shipment_id = OLD.shipment_id) THEN
            RAISE EXCEPTION 'Empty shipment';
        END IF;
        IF b IN ('picked', 'packed', 'shipped') AND (NOT EXISTS (
            SELECT
            FROM
                picking_tasks t
                JOIN shipment_items i USING (shipment_item_id)
            WHERE
                i.shipment_id = OLD.shipment_id
                AND t.status = 'completed') OR EXISTS (
        SELECT
        FROM
            shipment_items i
        WHERE
            i.shipment_id = OLD.shipment_id
                AND i.requested_quantity < (
                SELECT
                    COALESCE(SUM(picked_quantity), 0)
                FROM
                    picking_tasks
                WHERE
                    shipment_item_id = i.shipment_item_id
                    AND status = 'completed'))) THEN
            RAISE EXCEPTION 'Invalid picking quantities';
        END IF;
        IF b = 'shipped' AND EXISTS (
            SELECT
            FROM
                shipment_items i
            WHERE
                i.shipment_id = OLD.shipment_id
                AND (i.shipped_quantity <> (
                SELECT
                    COALESCE(SUM(picked_quantity), 0)
                FROM
                    picking_tasks
                WHERE
                    shipment_item_id = i.shipment_item_id
                    AND status = 'completed')
                OR i.shipped_quantity <> (
                SELECT
                    COALESCE(SUM(quantity), 0)
                FROM
                    stock_movements
                WHERE
                    shipment_item_id = i.shipment_item_id))) THEN
            RAISE EXCEPTION 'Shipment quantities must reconcile';
        END IF;
    IF (b = 'confirmed' AND NEW.confirmed_at IS NULL) OR (b = 'picked' AND
        NEW.picked_at IS NULL) OR (b = 'packed' AND NEW.packed_at IS NULL) OR (b =
        'shipped' AND NEW.shipped_at IS NULL) THEN
            RAISE EXCEPTION 'Stage timestamp required';
        END IF;
    END IF;
    IF b = 'cancelled' THEN
        NEW.cancelled_at := CURRENT_TIMESTAMP;
    END IF;
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END
$$;

CREATE TRIGGER receipts_guard
    BEFORE INSERT OR UPDATE OR DELETE ON receipts
    FOR EACH ROW
    EXECUTE FUNCTION document_guard ();

CREATE TRIGGER shipments_guard
    BEFORE INSERT OR UPDATE OR DELETE ON shipments
    FOR EACH ROW
    EXECUTE FUNCTION document_guard ();

CREATE FUNCTION item_guard ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    v_row JSONB;
    v_status TEXT;
    v_seller BIGINT;
    v_product BIGINT;
    v_parent BIGINT;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    v_row := CASE WHEN TG_OP = 'DELETE' THEN
        to_jsonb (OLD)
    ELSE
        to_jsonb (NEW)
    END;
    v_product := (v_row ->> 'product_id')::BIGINT;
    IF TG_OP = 'UPDATE' AND (NEW.product_id <> OLD.product_id OR (to_jsonb (NEW) ->>
    TG_ARGV[0]) IS DISTINCT FROM (to_jsonb (OLD) ->> TG_ARGV[0])) THEN
        RAISE EXCEPTION 'Line identity is immutable';
    END IF;
    v_parent := (v_row ->> TG_ARGV[0])::BIGINT;
    IF TG_TABLE_NAME = 'receipt_items' THEN
        SELECT
            status::TEXT,
            seller_id
        INTO
            v_status,
            v_seller
        FROM
            receipts
        WHERE
            receipt_id = v_parent
        FOR UPDATE;
    ELSE
        SELECT
            status::TEXT,
            seller_id
        INTO
            v_status,
            v_seller
        FROM
            shipments
        WHERE
            shipment_id = v_parent
        FOR UPDATE;
    END IF;
    IF v_status IS NULL OR v_status IN ('received', 'shipped', 'cancelled') THEN
        RAISE EXCEPTION 'Parent document is missing or final';
    END IF;
    IF TG_OP IN ('INSERT', 'DELETE') AND v_status <> 'created' THEN
        RAISE EXCEPTION 'Edit lines only in created status';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF TG_TABLE_NAME = 'receipt_items' THEN
            IF NEW.received_quantity <> 0 OR NEW.accepted_quantity <> 0 OR NEW.damaged_quantity <> 0 THEN
                RAISE EXCEPTION 'Receipt line must start empty';
            END IF;
        ELSE
            IF NEW.shipped_quantity <> 0 THEN
                RAISE EXCEPTION 'Shipment line must start empty';
            END IF;
        END IF;
    END IF;
    IF NOT EXISTS (
        SELECT
        FROM
            products p
            JOIN sellers s USING (seller_id)
        WHERE
            p.product_id = v_product
            AND p.seller_id = v_seller
            AND p.deleted_at IS NULL
            AND s.deleted_at IS NULL) THEN
        RAISE EXCEPTION 'Product must belong to active document seller';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF TG_TABLE_NAME = 'receipt_items' THEN
            IF NEW.expected_quantity <> OLD.expected_quantity AND v_status <> 'created' THEN
                RAISE EXCEPTION 'Expected quantity frozen';
            END IF;
            IF (NEW.received_quantity,
                NEW.accepted_quantity,
                NEW.damaged_quantity) IS DISTINCT FROM (OLD.received_quantity,
            OLD.accepted_quantity,
            OLD.damaged_quantity) AND v_status <> 'receiving' THEN
                RAISE EXCEPTION 'Receipt must be receiving';
            END IF;
        ELSE
            IF NEW.requested_quantity <> OLD.requested_quantity AND v_status <> 'created' THEN
                RAISE EXCEPTION 'Requested quantity frozen';
            END IF;
            IF NEW.shipped_quantity <> OLD.shipped_quantity AND v_status <> 'packed' THEN
                RAISE EXCEPTION 'Shipment must be packed';
            END IF;
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER receipt_items_guard
    BEFORE INSERT OR UPDATE OR DELETE ON receipt_items
    FOR EACH ROW
    EXECUTE FUNCTION item_guard ('receipt_id');

CREATE TRIGGER shipment_items_guard
    BEFORE INSERT OR UPDATE OR DELETE ON shipment_items
    FOR EACH ROW
    EXECUTE FUNCTION item_guard ('shipment_id');

CREATE FUNCTION picking_guard ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    v_status shipment_status;
    v_id BIGINT;
BEGIN
    PERFORM
        pg_advisory_xact_lock(48001, 1);
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Picking history cannot be deleted';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status IN ('completed', 'cancelled') THEN
            RAISE EXCEPTION 'Final picking task is immutable';
        END IF;
        IF (NEW.shipment_item_id,
            NEW.source_location_id,
            NEW.target_location_id,
            NEW.requested_quantity) IS DISTINCT FROM (OLD.shipment_item_id,
        OLD.source_location_id,
        OLD.target_location_id,
        OLD.requested_quantity) THEN
            RAISE EXCEPTION 'Picking allocation is immutable';
        END IF;
    IF NEW.status <> OLD.status AND NOT ((OLD.status = 'created' AND NEW.status IN
        ('in_progress', 'cancelled')) OR (OLD.status = 'in_progress' AND NEW.status
        IN ('completed', 'cancelled'))) THEN
            RAISE EXCEPTION 'Invalid picking transition';
        END IF;
    ELSIF NEW.status <> 'created'
            OR NEW.picked_quantity <> 0 THEN
            RAISE EXCEPTION 'Picking must start empty';
    END IF;
    SELECT
        s.status
    INTO
        v_status
    FROM
        shipments s
        JOIN shipment_items i USING (shipment_id)
    WHERE
        i.shipment_item_id = NEW.shipment_item_id
    FOR UPDATE
        OF s;
    IF v_status IS DISTINCT FROM 'confirmed' THEN
        RAISE EXCEPTION 'Confirmed shipment required';
    END IF;
    IF NEW.status = 'completed' AND (NEW.picked_quantity <> NEW.requested_quantity OR
    NEW.picked_quantity <> (
        SELECT
            COALESCE(SUM(quantity), 0)
        FROM
            stock_movements
        WHERE
            picking_task_id = NEW.picking_task_id)) THEN
        RAISE EXCEPTION 'Picking movement must reconcile';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER picking_guard
    BEFORE INSERT OR UPDATE OR DELETE ON picking_tasks
    FOR EACH ROW
    EXECUTE FUNCTION picking_guard ();

CREATE FUNCTION append_only_guard ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION '% is append-only', TG_TABLE_NAME;
END
$$;

CREATE TRIGGER stock_movements_append_only
    BEFORE UPDATE OR DELETE ON stock_movements
    FOR EACH ROW
    EXECUTE FUNCTION append_only_guard ();

CREATE TRIGGER audit_logs_append_only
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION append_only_guard ();

CREATE FUNCTION audit_row ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SET search_path = warehouse, public
    AS $$
DECLARE
    v_old JSONB;
    v_new JSONB;
    v_pk JSONB := '{}';
    k TEXT;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        v_old := to_jsonb (OLD);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        v_new := to_jsonb (NEW);
    END IF;
    FOREACH k IN ARRAY TG_ARGV LOOP
        v_pk := v_pk || jsonb_build_object(
            k, COALESCE(v_new, v_old) -> k
        );
    END LOOP;
    INSERT INTO audit_logs (table_name, record_pk, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, v_pk, lower(TG_OP)::audit_operation, v_old, v_new);
    RETURN NULL;
END
$$;

CREATE TRIGGER receipts_audit
    AFTER INSERT OR UPDATE OR DELETE ON receipts
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('receipt_id');

CREATE TRIGGER receipt_items_audit
    AFTER INSERT OR UPDATE OR DELETE ON receipt_items
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('receipt_item_id');

CREATE TRIGGER shipments_audit
    AFTER INSERT OR UPDATE OR DELETE ON shipments
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('shipment_id');

CREATE TRIGGER shipment_items_audit
    AFTER INSERT OR UPDATE OR DELETE ON shipment_items
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('shipment_item_id');

CREATE TRIGGER picking_audit
    AFTER INSERT OR UPDATE OR DELETE ON picking_tasks
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('picking_task_id');

CREATE TRIGGER inventory_audit
    AFTER INSERT OR UPDATE OR DELETE ON inventory
    FOR EACH ROW
    EXECUTE FUNCTION audit_row ('product_id', 'location_id');

COMMIT;
