SET search_path TO warehouse, public;

DO $$
DECLARE
    missing_tables TEXT[];
    extra_tables TEXT[];
BEGIN
    WITH expected_tables (
        table_name
    ) AS (
        VALUES ('audit_logs'),
            ('employees'),
            ('inventory'),
            ('inventory_count_items'),
            ('inventory_counts'),
            ('picking_tasks'),
            ('product_categories'),
            ('products'),
            ('receipt_items'),
            ('receipts'),
            ('sellers'),
            ('shipment_items'),
            ('shipments'),
            ('sorting_centers'),
            ('stock_movements'),
            ('warehouse_locations')
    )
    SELECT
        ARRAY_AGG(table_name ORDER BY table_name)
    INTO
        missing_tables
    FROM (
        SELECT
            table_name
        FROM
            expected_tables
        EXCEPT
        SELECT
            table_name
        FROM
            information_schema.tables
        WHERE
            table_schema = 'warehouse'
            AND table_type = 'BASE TABLE') AS missing;

        WITH expected_tables (
            table_name
        ) AS (
            VALUES ('audit_logs'),
                ('employees'),
                ('inventory'),
                ('inventory_count_items'),
                ('inventory_counts'),
                ('picking_tasks'),
                ('product_categories'),
                ('products'),
                ('receipt_items'),
                ('receipts'),
                ('sellers'),
                ('shipment_items'),
                ('shipments'),
                ('sorting_centers'),
                ('stock_movements'),
                ('warehouse_locations')
        )
        SELECT
            ARRAY_AGG(table_name ORDER BY table_name)
        INTO
            extra_tables
        FROM (
            SELECT
                table_name
            FROM
                information_schema.tables
            WHERE
                table_schema = 'warehouse'
                AND table_type = 'BASE TABLE'
            EXCEPT
            SELECT
                table_name
            FROM
                expected_tables) AS extra;

        IF missing_tables IS NOT NULL OR extra_tables IS NOT NULL THEN
        RAISE EXCEPTION 'Schema mismatch. Missing: %, extra: %', COALESCE(missing_tables, ARRAY[]::TEXT[]),
        COALESCE(extra_tables, ARRAY[]::TEXT[]);
        END IF;
END;
$$;

SELECT
    table_name
FROM
    information_schema.tables
WHERE
    table_schema = 'warehouse'
    AND table_type = 'BASE TABLE'
ORDER BY
    table_name;
