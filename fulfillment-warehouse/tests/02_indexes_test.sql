SET search_path TO warehouse, public;

DO $$
DECLARE
    missing_indexes TEXT[];
BEGIN
    WITH expected_indexes (
        index_name
    ) AS (
        VALUES ('idx_audit_logs_record_history'),
            ('idx_inventory_count_items_location'),
            ('idx_picking_tasks_assignee_open'),
            ('idx_picking_tasks_source_open'),
            ('idx_products_category_active'),
            ('idx_products_seller_active'),
            ('idx_receipt_items_product'),
            ('idx_receipts_center_status_created'),
            ('idx_receipts_seller_status_created'),
            ('idx_receipts_source_shipment'),
            ('idx_shipment_items_product'),
            ('idx_shipments_center_status_created'),
            ('idx_shipments_seller_status_created'),
            ('idx_stock_movements_count_item'),
            ('idx_stock_movements_from_location_created'),
            ('idx_stock_movements_picking_task'),
            ('idx_stock_movements_product_created'),
            ('idx_stock_movements_receipt_item'),
            ('idx_stock_movements_shipment_item'),
            ('idx_stock_movements_to_location_created'),
            ('idx_warehouse_locations_parent_active')
    )
    SELECT
        ARRAY_AGG(index_name ORDER BY index_name)
    INTO
        missing_indexes
    FROM (
        SELECT
            index_name
        FROM
            expected_indexes
        EXCEPT
        SELECT
            indexname
        FROM
            pg_indexes
        WHERE
            schemaname = 'warehouse') AS missing;

        IF missing_indexes IS NOT NULL THEN
            RAISE EXCEPTION 'Missing indexes: %', missing_indexes;
        END IF;
END;
$$;

SELECT
    indexname,
    tablename
FROM
    pg_indexes
WHERE
    schemaname = 'warehouse'
    AND indexname LIKE 'idx_%'
ORDER BY
    tablename,
    indexname;
