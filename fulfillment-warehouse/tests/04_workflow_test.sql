-- Проверяем данные и запреты изменений. Попытки изменений откатываются в подтранзакциях.
DO $$
DECLARE
    r RECORD;
    n BIGINT;
    emp BIGINT;
BEGIN
    SELECT
        COUNT(*)
    INTO
        n
    FROM
        warehouse.receipts
    WHERE
        status = 'received';
    IF n = 0 THEN
        RAISE EXCEPTION 'Generate data before running this test';
    END IF;
    IF EXISTS (
        SELECT
        FROM
            warehouse.v_inventory_reconciliation) THEN
        RAISE EXCEPTION 'Inventory does not match movement history';
    END IF;
    IF EXISTS (
        SELECT
        FROM
            warehouse.receipt_items
        WHERE
            received_quantity <> accepted_quantity + damaged_quantity) THEN
        RAISE EXCEPTION 'Receipt quantities inconsistent';
    END IF;
    IF EXISTS (
        SELECT
        FROM
            warehouse.shipments
        WHERE
            status <> 'shipped') THEN
        RAISE EXCEPTION 'Generator should finish every shipment';
    END IF;
    SELECT
        shipment_id
    INTO
        r
    FROM
        warehouse.shipments
    LIMIT 1;
    SELECT
        MIN(employee_id)
    INTO
        emp
    FROM
        warehouse.employees;
    BEGIN
        CALL warehouse.dispatch_shipment (r.shipment_id, emp);
        RAISE EXCEPTION
            USING ERRCODE = 'ZX001', MESSAGE = 'Repeated dispatch accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'ZX001' THEN
                RAISE;
                END IF;
    END;
    BEGIN
        UPDATE
            warehouse.shipments
        SET
            status = 'created'
        WHERE
            shipment_id = r.shipment_id;
            RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Final document edit accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'ZX001' THEN
                RAISE;
                END IF;
    END;
    BEGIN
        UPDATE
            warehouse.shipment_items
        SET
            requested_quantity = requested_quantity + 1
        WHERE
            shipment_id = r.shipment_id;
            RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Final line edit accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'ZX001' THEN
                RAISE;
                END IF;
    END;
    BEGIN
        DELETE FROM warehouse.stock_movements;
        RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Movement deletion accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLSTATE = 'ZX001' THEN
                RAISE;
                END IF;
    END;
    IF NOT EXISTS (
        SELECT
        FROM
            warehouse.audit_logs
        WHERE
            table_name = 'inventory') THEN
        RAISE EXCEPTION 'Audit missing';
        END IF;
        RAISE NOTICE 'Workflow test passed';
END
$$;
