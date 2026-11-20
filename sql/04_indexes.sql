BEGIN;

SET LOCAL search_path TO warehouse, public;

-- Удаленные товары остаются в истории, но исключаются из поиска по каталогу.
CREATE INDEX idx_products_seller_active ON products (seller_id)
WHERE
    deleted_at IS NULL;

CREATE INDEX idx_products_category_active ON products (category_id)
WHERE
    deleted_at IS NULL;

CREATE INDEX idx_warehouse_locations_parent_active ON warehouse_locations (parent_location_id)
WHERE
    deleted_at IS NULL;

CREATE INDEX idx_shipments_seller_status_created ON shipments (seller_id, status, created_at DESC);

CREATE INDEX idx_shipments_center_status_created ON shipments (sorting_center_id, status, created_at DESC);

CREATE INDEX idx_shipment_items_product ON shipment_items (product_id);

CREATE INDEX idx_receipts_seller_status_created ON receipts (seller_id, status, created_at DESC);

CREATE INDEX idx_receipts_center_status_created ON receipts (sorting_center_id, status, created_at DESC)
WHERE
    sorting_center_id IS NOT NULL;

CREATE INDEX idx_receipts_source_shipment ON receipts (source_shipment_id)
WHERE
    source_shipment_id IS NOT NULL;

CREATE INDEX idx_receipt_items_product ON receipt_items (product_id);

CREATE INDEX idx_inventory_count_items_location ON inventory_count_items (location_id, inventory_count_id);

-- Рабочие индексы содержат только незавершенные задания сборки.
CREATE INDEX idx_picking_tasks_assignee_open ON picking_tasks (assigned_employee_id, status, created_at)
WHERE
    status IN ('created', 'in_progress');

CREATE INDEX idx_picking_tasks_source_open ON picking_tasks (source_location_id, status, created_at)
WHERE
    status IN ('created', 'in_progress');

CREATE INDEX idx_stock_movements_product_created ON stock_movements (product_id, created_at DESC);

CREATE INDEX idx_stock_movements_from_location_created ON stock_movements (from_location_id, created_at DESC)
WHERE
    from_location_id IS NOT NULL;

CREATE INDEX idx_stock_movements_to_location_created ON stock_movements (to_location_id, created_at DESC)
WHERE
    to_location_id IS NOT NULL;

-- Поиск движений по документу-основанию.
CREATE INDEX idx_stock_movements_receipt_item ON stock_movements (receipt_item_id)
WHERE
    receipt_item_id IS NOT NULL;

CREATE INDEX idx_stock_movements_shipment_item ON stock_movements (shipment_item_id)
WHERE
    shipment_item_id IS NOT NULL;

CREATE INDEX idx_stock_movements_picking_task ON stock_movements (picking_task_id)
WHERE
    picking_task_id IS NOT NULL;

CREATE INDEX idx_stock_movements_count_item ON stock_movements (inventory_count_item_id)
WHERE
    inventory_count_item_id IS NOT NULL;

CREATE INDEX idx_audit_logs_record_history ON audit_logs (table_name, record_pk, changed_at DESC);

COMMIT;
