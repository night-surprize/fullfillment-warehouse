BEGIN;

SET LOCAL search_path TO warehouse, public;

CREATE TABLE shipments (
    shipment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    shipment_number VARCHAR(50) NOT NULL,
    seller_id BIGINT NOT NULL,
    sorting_center_id BIGINT NOT NULL,
    created_by_employee_id BIGINT NOT NULL,
    status shipment_status NOT NULL DEFAULT 'created',
    confirmed_at TIMESTAMPTZ,
    picked_at TIMESTAMPTZ,
    packed_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipments PRIMARY KEY (shipment_id),
    CONSTRAINT fk_shipments_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON UPDATE
    RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_shipments_sorting_center FOREIGN KEY (sorting_center_id) REFERENCES
    sorting_centers (sorting_center_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_shipments_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES
    employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_shipments_shipment_number UNIQUE (shipment_number),
    CONSTRAINT ck_shipments_number_not_blank CHECK (BTRIM(shipment_number) <> ''),
    CONSTRAINT ck_shipments_confirmed_at CHECK (confirmed_at IS NULL OR confirmed_at >= created_at),
    CONSTRAINT ck_shipments_picked_at CHECK (picked_at IS NULL OR (picked_at >= created_at AND
    (confirmed_at IS NULL OR picked_at >= confirmed_at))),
    CONSTRAINT ck_shipments_packed_at CHECK (packed_at IS NULL OR (packed_at >= created_at AND
    (confirmed_at IS NULL OR packed_at >= confirmed_at) AND (picked_at IS NULL OR packed_at >=
    picked_at))),
    CONSTRAINT ck_shipments_shipped_at CHECK (shipped_at IS NULL OR (shipped_at >= created_at AND
    (packed_at IS NULL OR shipped_at >= packed_at))),
    CONSTRAINT ck_shipments_cancelled_at CHECK (cancelled_at IS NULL OR cancelled_at >= created_at)
);

CREATE TABLE shipment_items (
    shipment_item_id BIGINT GENERATED ALWAYS AS IDENTITY,
    shipment_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    requested_quantity INTEGER NOT NULL,
    shipped_quantity INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT pk_shipment_items PRIMARY KEY (shipment_item_id),
    CONSTRAINT fk_shipment_items_shipment FOREIGN KEY (shipment_id) REFERENCES shipments
    (shipment_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_shipment_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_shipment_items_shipment_product UNIQUE (shipment_id, product_id),
    CONSTRAINT ck_shipment_items_requested_positive CHECK (requested_quantity > 0),
    CONSTRAINT ck_shipment_items_shipped_valid CHECK (shipped_quantity >= 0 AND shipped_quantity <=
    requested_quantity)
);

CREATE TABLE receipts (
    receipt_id BIGINT GENERATED ALWAYS AS IDENTITY,
    receipt_number VARCHAR(50) NOT NULL,
    receipt_type receipt_type NOT NULL,
    status receipt_status NOT NULL DEFAULT 'created',
    seller_id BIGINT NOT NULL,
    sorting_center_id BIGINT,
    source_shipment_id BIGINT,
    created_by_employee_id BIGINT NOT NULL,
    processed_by_employee_id BIGINT,
    expected_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_receipts PRIMARY KEY (receipt_id),
    CONSTRAINT fk_receipts_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON UPDATE
    RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_receipts_sorting_center FOREIGN KEY (sorting_center_id) REFERENCES
    sorting_centers (sorting_center_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_receipts_source_shipment FOREIGN KEY (source_shipment_id) REFERENCES shipments
    (shipment_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_receipts_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES
    employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_receipts_processed_by_employee FOREIGN KEY (processed_by_employee_id) REFERENCES
    employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_receipts_receipt_number UNIQUE (receipt_number),
    CONSTRAINT ck_receipts_number_not_blank CHECK (BTRIM(receipt_number) <> ''),
    CONSTRAINT ck_receipts_source_by_type CHECK ((receipt_type = 'supplier' AND
    sorting_center_id IS NULL AND source_shipment_id IS NULL) OR (receipt_type = 'return'
    AND sorting_center_id IS NOT NULL)),
    CONSTRAINT ck_receipts_expected_at CHECK (expected_at IS NULL OR expected_at >= created_at),
    CONSTRAINT ck_receipts_started_at CHECK (started_at IS NULL OR started_at >= created_at),
    CONSTRAINT ck_receipts_completed_at CHECK (completed_at IS NULL OR (completed_at >= created_at
    AND (started_at IS NULL OR completed_at >= started_at))),
    CONSTRAINT ck_receipts_cancelled_at CHECK (cancelled_at IS NULL OR cancelled_at >= created_at)
);

CREATE TABLE receipt_items (
    receipt_item_id BIGINT GENERATED ALWAYS AS IDENTITY,
    receipt_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    expected_quantity INTEGER NOT NULL,
    received_quantity INTEGER NOT NULL DEFAULT 0,
    accepted_quantity INTEGER NOT NULL DEFAULT 0,
    damaged_quantity INTEGER NOT NULL DEFAULT 0,
    discrepancy_note TEXT,
    CONSTRAINT pk_receipt_items PRIMARY KEY (receipt_item_id),
    CONSTRAINT fk_receipt_items_receipt FOREIGN KEY (receipt_id) REFERENCES receipts (receipt_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_receipt_items_product FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_receipt_items_receipt_product UNIQUE (receipt_id, product_id),
    CONSTRAINT ck_receipt_items_expected_nonnegative CHECK (expected_quantity >= 0),
    CONSTRAINT ck_receipt_items_received_nonnegative CHECK (received_quantity >= 0),
    CONSTRAINT ck_receipt_items_accepted_nonnegative CHECK (accepted_quantity >= 0),
    CONSTRAINT ck_receipt_items_damaged_nonnegative CHECK (damaged_quantity >= 0),
    CONSTRAINT ck_receipt_items_distribution CHECK (accepted_quantity + damaged_quantity <= received_quantity)
);

CREATE TABLE inventory_counts (
    inventory_count_id BIGINT GENERATED ALWAYS AS IDENTITY,
    count_number VARCHAR(50) NOT NULL,
    status inventory_count_status NOT NULL DEFAULT 'created',
    created_by_employee_id BIGINT NOT NULL,
    performed_by_employee_id BIGINT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory_counts PRIMARY KEY (inventory_count_id),
    CONSTRAINT fk_inventory_counts_created_by_employee FOREIGN KEY (created_by_employee_id)
    REFERENCES employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_counts_performed_by_employee FOREIGN KEY (performed_by_employee_id)
    REFERENCES employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_inventory_counts_count_number UNIQUE (count_number),
    CONSTRAINT ck_inventory_counts_number_not_blank CHECK (BTRIM(count_number) <> ''),
    CONSTRAINT ck_inventory_counts_started_at CHECK (started_at IS NULL OR started_at >= created_at),
    CONSTRAINT ck_inventory_counts_completed_at CHECK (completed_at IS NULL OR (completed_at >=
    created_at AND (started_at IS NULL OR completed_at >= started_at)))
);

CREATE TABLE inventory_count_items (
    inventory_count_item_id BIGINT GENERATED ALWAYS AS IDENTITY,
    inventory_count_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    location_id BIGINT NOT NULL,
    expected_quantity INTEGER NOT NULL,
    actual_quantity INTEGER,
    difference_quantity INTEGER GENERATED ALWAYS AS (actual_quantity - expected_quantity) STORED,
    CONSTRAINT pk_inventory_count_items PRIMARY KEY (inventory_count_item_id),
    CONSTRAINT fk_inventory_count_items_count FOREIGN KEY (inventory_count_id) REFERENCES
    inventory_counts (inventory_count_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_count_items_product FOREIGN KEY (product_id) REFERENCES products
    (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_count_items_location FOREIGN KEY (location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_inventory_count_items_count_location UNIQUE (inventory_count_id, location_id),
    CONSTRAINT ck_inventory_count_items_expected_nonnegative CHECK (expected_quantity >= 0),
    CONSTRAINT ck_inventory_count_items_actual_nonnegative CHECK (actual_quantity IS NULL OR actual_quantity >= 0)
);

CREATE TABLE picking_tasks (
    picking_task_id BIGINT GENERATED ALWAYS AS IDENTITY,
    shipment_item_id BIGINT NOT NULL,
    source_location_id BIGINT NOT NULL,
    target_location_id BIGINT NOT NULL,
    assigned_employee_id BIGINT,
    status picking_status NOT NULL DEFAULT 'created',
    requested_quantity INTEGER NOT NULL,
    picked_quantity INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    CONSTRAINT pk_picking_tasks PRIMARY KEY (picking_task_id),
    CONSTRAINT fk_picking_tasks_shipment_item FOREIGN KEY (shipment_item_id) REFERENCES
    shipment_items (shipment_item_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_picking_tasks_source_location FOREIGN KEY (source_location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_picking_tasks_target_location FOREIGN KEY (target_location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_picking_tasks_assigned_employee FOREIGN KEY (assigned_employee_id) REFERENCES
    employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_picking_tasks_item_route UNIQUE (shipment_item_id, source_location_id, target_location_id),
    CONSTRAINT ck_picking_tasks_locations_different CHECK (source_location_id <> target_location_id),
    CONSTRAINT ck_picking_tasks_requested_positive CHECK (requested_quantity > 0),
    CONSTRAINT ck_picking_tasks_picked_valid CHECK (picked_quantity >= 0 AND picked_quantity <=
    requested_quantity),
    CONSTRAINT ck_picking_tasks_started_at CHECK (started_at IS NULL OR started_at >= created_at),
    CONSTRAINT ck_picking_tasks_completed_at CHECK (completed_at IS NULL OR (completed_at >=
    created_at AND (started_at IS NULL OR completed_at >= started_at)))
);

CREATE TABLE inventory (
    product_id BIGINT NOT NULL,
    location_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory PRIMARY KEY (product_id, location_id),
    CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON
    UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_location FOREIGN KEY (location_id) REFERENCES warehouse_locations
    (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_inventory_location UNIQUE (location_id),
    CONSTRAINT ck_inventory_quantity_positive CHECK (quantity > 0)
);

CREATE TABLE stock_movements (
    movement_id BIGINT GENERATED ALWAYS AS IDENTITY,
    movement_type movement_type NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    from_location_id BIGINT,
    to_location_id BIGINT,
    performed_by_employee_id BIGINT NOT NULL,
    receipt_item_id BIGINT,
    shipment_item_id BIGINT,
    picking_task_id BIGINT,
    inventory_count_item_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_stock_movements PRIMARY KEY (movement_id),
    CONSTRAINT fk_stock_movements_product FOREIGN KEY (product_id) REFERENCES products (product_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_from_location FOREIGN KEY (from_location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_to_location FOREIGN KEY (to_location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_employee FOREIGN KEY (performed_by_employee_id) REFERENCES
    employees (employee_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_receipt_item FOREIGN KEY (receipt_item_id) REFERENCES
    receipt_items (receipt_item_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_shipment_item FOREIGN KEY (shipment_item_id) REFERENCES
    shipment_items (shipment_item_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_picking_task FOREIGN KEY (picking_task_id) REFERENCES
    picking_tasks (picking_task_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movements_inventory_count_item FOREIGN KEY (inventory_count_item_id)
    REFERENCES inventory_count_items (inventory_count_item_id) ON UPDATE RESTRICT ON DELETE
    RESTRICT,
    CONSTRAINT ck_stock_movements_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ck_stock_movements_locations_different CHECK (from_location_id IS NULL OR
    to_location_id IS NULL OR from_location_id <> to_location_id),
    CONSTRAINT ck_stock_movements_route CHECK ((movement_type IN ('receipt', 'return_receipt',
    'inventory_surplus') AND from_location_id IS NULL AND to_location_id IS NOT NULL) OR
    (movement_type IN ('shipment', 'inventory_shortage') AND from_location_id IS NOT NULL AND
    to_location_id IS NULL) OR (movement_type IN ('transfer', 'damage_transfer',
    'picking') AND from_location_id IS NOT NULL AND to_location_id IS NOT NULL)),
    CONSTRAINT ck_stock_movements_document_source CHECK ((movement_type IN ('receipt',
    'return_receipt') AND receipt_item_id IS NOT NULL AND NUM_NONNULLS (receipt_item_id,
    shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type =
    'shipment' AND shipment_item_id IS NOT NULL AND NUM_NONNULLS (receipt_item_id,
    shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type =
    'picking' AND picking_task_id IS NOT NULL AND NUM_NONNULLS (receipt_item_id,
    shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type IN
    ('inventory_surplus', 'inventory_shortage') AND inventory_count_item_id IS NOT NULL AND NUM_NONNULLS
    (receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR
    (movement_type IN ('transfer', 'damage_transfer') AND NUM_NONNULLS (receipt_item_id,
    shipment_item_id, picking_task_id, inventory_count_item_id) = 0))
);

CREATE TABLE audit_logs (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY,
    employee_id BIGINT,
    table_name TEXT NOT NULL,
    record_pk JSONB NOT NULL,
    operation audit_operation NOT NULL,
    old_data JSONB,
    new_data JSONB,
    database_user TEXT NOT NULL DEFAULT CURRENT_USER,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit_logs PRIMARY KEY (audit_id),
    CONSTRAINT fk_audit_logs_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_audit_logs_table_name_not_blank CHECK (BTRIM(table_name) <> ''),
    CONSTRAINT ck_audit_logs_record_pk_object CHECK (JSONB_TYPEOF(record_pk) = 'object'),
    CONSTRAINT ck_audit_logs_row_images CHECK ((operation = 'insert' AND old_data IS NULL
    AND new_data IS NOT NULL) OR (operation = 'update' AND old_data IS NOT NULL AND
    new_data IS NOT NULL) OR (operation = 'delete' AND old_data IS NOT NULL AND new_data
    IS NULL))
);

COMMIT;
