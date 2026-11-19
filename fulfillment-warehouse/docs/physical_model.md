# Physical model

All tables are in the warehouse schema. Fields and constraints follow migrations
01-03; business triggers follow in 07. Weight is kg, volume is m3, quantities
are integer units. NUMERIC avoids floating-point rounding. TIMESTAMPTZ records
an instant, displayed in the current session timezone.

## ENUM types

- `location_kind`: `warehouse`, `zone`, `aisle`, `rack`, `cell`
- `zone_purpose`: `receiving`, `storage`, `damaged`, `packing`, `shipping`
- `receipt_type`: `supplier`, `return`
- `receipt_status`: `created`, `expected`, `receiving`, `received`, `cancelled`
- `shipment_status`: `created`, `confirmed`, `picked`, `packed`, `shipped`, `cancelled`
- `picking_status`: `created`, `in_progress`, `completed`, `cancelled`
- `inventory_count_status`: `created`, `in_progress`, `completed`, `cancelled`
- `movement_type`: `receipt`, `return_receipt`, `transfer`, `damage_transfer`, `picking`, `shipment`, `inventory_surplus`, `inventory_shortage`
- `audit_operation`: `insert`, `update`, `delete`

## sellers

| Column | SQL definition | Nullable |
|---|---|---|
| `seller_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `seller_code` | `varchar(30) NOT NULL` | no |
| `name` | `varchar(200) NOT NULL` | no |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_sellers PRIMARY KEY (seller_id)`
- `CONSTRAINT uq_sellers_seller_code UNIQUE (seller_code)`
- `CONSTRAINT ck_sellers_code_not_blank CHECK (btrim(seller_code) <> '')`
- `CONSTRAINT ck_sellers_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_sellers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## product_categories

| Column | SQL definition | Nullable |
|---|---|---|
| `category_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `parent_category_id` | `bigint` | yes |
| `name` | `varchar(150) NOT NULL` | no |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_product_categories PRIMARY KEY (category_id)`
- `CONSTRAINT fk_product_categories_parent FOREIGN KEY (parent_category_id) REFERENCES product_categories (category_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_product_categories_parent_name UNIQUE NULLS NOT DISTINCT (parent_category_id, name)`
- `CONSTRAINT ck_product_categories_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_product_categories_not_own_parent CHECK (parent_category_id IS NULL OR parent_category_id <> category_id)`
- `CONSTRAINT ck_product_categories_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## employees

| Column | SQL definition | Nullable |
|---|---|---|
| `employee_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `employee_code` | `varchar(30) NOT NULL` | no |
| `full_name` | `varchar(200) NOT NULL` | no |
| `email` | `varchar(254)` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_employees PRIMARY KEY (employee_id)`
- `CONSTRAINT uq_employees_employee_code UNIQUE (employee_code)`
- `CONSTRAINT uq_employees_email UNIQUE (email)`
- `CONSTRAINT ck_employees_code_not_blank CHECK (btrim(employee_code) <> '')`
- `CONSTRAINT ck_employees_name_not_blank CHECK (btrim(full_name) <> '')`
- `CONSTRAINT ck_employees_email_not_blank CHECK (email IS NULL OR btrim(email) <> '')`
- `CONSTRAINT ck_employees_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## sorting_centers

| Column | SQL definition | Nullable |
|---|---|---|
| `sorting_center_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `center_code` | `varchar(30) NOT NULL` | no |
| `name` | `varchar(200) NOT NULL` | no |
| `address` | `text NOT NULL` | no |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_sorting_centers PRIMARY KEY (sorting_center_id)`
- `CONSTRAINT uq_sorting_centers_center_code UNIQUE (center_code)`
- `CONSTRAINT ck_sorting_centers_code_not_blank CHECK (btrim(center_code) <> '')`
- `CONSTRAINT ck_sorting_centers_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_sorting_centers_address_not_blank CHECK (btrim(address) <> '')`
- `CONSTRAINT ck_sorting_centers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## products

| Column | SQL definition | Nullable |
|---|---|---|
| `product_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `seller_id` | `bigint NOT NULL` | no |
| `category_id` | `bigint NOT NULL` | no |
| `sku` | `varchar(100) NOT NULL` | no |
| `name` | `varchar(200) NOT NULL` | no |
| `unit_weight_kg` | `numeric(10, 3) NOT NULL` | no |
| `unit_volume_m3` | `numeric(12, 6) NOT NULL` | no |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_products PRIMARY KEY (product_id)`
- `CONSTRAINT fk_products_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories (category_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_products_sku UNIQUE (sku)`
- `CONSTRAINT ck_products_sku_not_blank CHECK (btrim(sku) <> '')`
- `CONSTRAINT ck_products_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_products_weight_positive CHECK (unit_weight_kg > 0)`
- `CONSTRAINT ck_products_volume_positive CHECK (unit_volume_m3 > 0)`
- `CONSTRAINT ck_products_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## warehouse_locations

| Column | SQL definition | Nullable |
|---|---|---|
| `location_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `parent_location_id` | `bigint` | yes |
| `location_code` | `varchar(50) NOT NULL` | no |
| `name` | `varchar(150) NOT NULL` | no |
| `location_kind` | `location_kind NOT NULL` | no |
| `zone_purpose` | `zone_purpose` | yes |
| `max_weight_kg` | `numeric(12, 3)` | yes |
| `max_volume_m3` | `numeric(12, 6)` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `deleted_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_warehouse_locations PRIMARY KEY (location_id)`
- `CONSTRAINT fk_warehouse_locations_parent FOREIGN KEY (parent_location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_warehouse_locations_code UNIQUE (location_code)`
- `CONSTRAINT ck_warehouse_locations_code_not_blank CHECK (btrim(location_code) <> '')`
- `CONSTRAINT ck_warehouse_locations_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_warehouse_locations_not_own_parent CHECK (parent_location_id IS NULL OR parent_location_id <> location_id)`
- `CONSTRAINT ck_warehouse_locations_root CHECK ((location_kind = 'warehouse' AND parent_location_id IS NULL) OR (location_kind <> 'warehouse' AND parent_location_id IS NOT NULL))`
- `CONSTRAINT ck_warehouse_locations_zone_purpose CHECK ((location_kind = 'zone' AND zone_purpose IS NOT NULL) OR (location_kind <> 'zone' AND zone_purpose IS NULL))`
- `CONSTRAINT ck_warehouse_locations_cell_capacity CHECK ((location_kind = 'cell' AND max_weight_kg IS NOT NULL AND max_volume_m3 IS NOT NULL AND max_weight_kg > 0 AND max_volume_m3 > 0) OR (location_kind <> 'cell' AND max_weight_kg IS NULL AND max_volume_m3 IS NULL))`
- `CONSTRAINT ck_warehouse_locations_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## shipments

| Column | SQL definition | Nullable |
|---|---|---|
| `shipment_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `shipment_number` | `varchar(50) NOT NULL` | no |
| `seller_id` | `bigint NOT NULL` | no |
| `sorting_center_id` | `bigint NOT NULL` | no |
| `created_by_employee_id` | `bigint NOT NULL` | no |
| `status` | `shipment_status NOT NULL DEFAULT 'created'` | no |
| `confirmed_at` | `timestamptz` | yes |
| `picked_at` | `timestamptz` | yes |
| `packed_at` | `timestamptz` | yes |
| `shipped_at` | `timestamptz` | yes |
| `cancelled_at` | `timestamptz` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_shipments PRIMARY KEY (shipment_id)`
- `CONSTRAINT fk_shipments_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_shipments_sorting_center FOREIGN KEY (sorting_center_id) REFERENCES sorting_centers (sorting_center_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_shipments_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_shipments_shipment_number UNIQUE (shipment_number)`
- `CONSTRAINT ck_shipments_number_not_blank CHECK (btrim(shipment_number) <> '')`
- `CONSTRAINT ck_shipments_confirmed_at CHECK (confirmed_at IS NULL OR confirmed_at >= created_at)`
- `CONSTRAINT ck_shipments_picked_at CHECK (picked_at IS NULL OR (picked_at >= created_at AND (confirmed_at IS NULL OR picked_at >= confirmed_at)))`
- `CONSTRAINT ck_shipments_packed_at CHECK (packed_at IS NULL OR (packed_at >= created_at AND (confirmed_at IS NULL OR packed_at >= confirmed_at) AND (picked_at IS NULL OR packed_at >= picked_at)))`
- `CONSTRAINT ck_shipments_shipped_at CHECK (shipped_at IS NULL OR (shipped_at >= created_at AND (packed_at IS NULL OR shipped_at >= packed_at)))`
- `CONSTRAINT ck_shipments_cancelled_at CHECK (cancelled_at IS NULL OR cancelled_at >= created_at)`

## shipment_items

| Column | SQL definition | Nullable |
|---|---|---|
| `shipment_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `shipment_id` | `bigint NOT NULL` | no |
| `product_id` | `bigint NOT NULL` | no |
| `requested_quantity` | `integer NOT NULL` | no |
| `shipped_quantity` | `integer NOT NULL DEFAULT 0` | no |

Constraints:

- `CONSTRAINT pk_shipment_items PRIMARY KEY (shipment_item_id)`
- `CONSTRAINT fk_shipment_items_shipment FOREIGN KEY (shipment_id) REFERENCES shipments (shipment_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_shipment_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_shipment_items_shipment_product UNIQUE (shipment_id, product_id)`
- `CONSTRAINT ck_shipment_items_requested_positive CHECK (requested_quantity > 0)`
- `CONSTRAINT ck_shipment_items_shipped_valid CHECK (shipped_quantity >= 0 AND shipped_quantity <= requested_quantity)`

## receipts

| Column | SQL definition | Nullable |
|---|---|---|
| `receipt_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `receipt_number` | `varchar(50) NOT NULL` | no |
| `receipt_type` | `receipt_type NOT NULL` | no |
| `status` | `receipt_status NOT NULL DEFAULT 'created'` | no |
| `seller_id` | `bigint NOT NULL` | no |
| `sorting_center_id` | `bigint` | yes |
| `source_shipment_id` | `bigint` | yes |
| `created_by_employee_id` | `bigint NOT NULL` | no |
| `processed_by_employee_id` | `bigint` | yes |
| `expected_at` | `timestamptz` | yes |
| `started_at` | `timestamptz` | yes |
| `completed_at` | `timestamptz` | yes |
| `cancelled_at` | `timestamptz` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_receipts PRIMARY KEY (receipt_id)`
- `CONSTRAINT fk_receipts_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipts_sorting_center FOREIGN KEY (sorting_center_id) REFERENCES sorting_centers (sorting_center_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipts_source_shipment FOREIGN KEY (source_shipment_id) REFERENCES shipments (shipment_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipts_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipts_processed_by_employee FOREIGN KEY (processed_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_receipts_receipt_number UNIQUE (receipt_number)`
- `CONSTRAINT ck_receipts_number_not_blank CHECK (btrim(receipt_number) <> '')`
- `CONSTRAINT ck_receipts_source_by_type CHECK ((receipt_type = 'supplier' AND sorting_center_id IS NULL AND source_shipment_id IS NULL) OR (receipt_type = 'return' AND sorting_center_id IS NOT NULL))`
- `CONSTRAINT ck_receipts_expected_at CHECK (expected_at IS NULL OR expected_at >= created_at)`
- `CONSTRAINT ck_receipts_started_at CHECK (started_at IS NULL OR started_at >= created_at)`
- `CONSTRAINT ck_receipts_completed_at CHECK (completed_at IS NULL OR (completed_at >= created_at AND (started_at IS NULL OR completed_at >= started_at)))`
- `CONSTRAINT ck_receipts_cancelled_at CHECK (cancelled_at IS NULL OR cancelled_at >= created_at)`

## receipt_items

| Column | SQL definition | Nullable |
|---|---|---|
| `receipt_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `receipt_id` | `bigint NOT NULL` | no |
| `product_id` | `bigint NOT NULL` | no |
| `expected_quantity` | `integer NOT NULL` | no |
| `received_quantity` | `integer NOT NULL DEFAULT 0` | no |
| `accepted_quantity` | `integer NOT NULL DEFAULT 0` | no |
| `damaged_quantity` | `integer NOT NULL DEFAULT 0` | no |
| `discrepancy_note` | `text` | yes |

Constraints:

- `CONSTRAINT pk_receipt_items PRIMARY KEY (receipt_item_id)`
- `CONSTRAINT fk_receipt_items_receipt FOREIGN KEY (receipt_id) REFERENCES receipts (receipt_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipt_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_receipt_items_receipt_product UNIQUE (receipt_id, product_id)`
- `CONSTRAINT ck_receipt_items_expected_nonnegative CHECK (expected_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_received_nonnegative CHECK (received_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_accepted_nonnegative CHECK (accepted_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_damaged_nonnegative CHECK (damaged_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_distribution CHECK (accepted_quantity + damaged_quantity <= received_quantity)`

## inventory_counts

| Column | SQL definition | Nullable |
|---|---|---|
| `inventory_count_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `count_number` | `varchar(50) NOT NULL` | no |
| `status` | `inventory_count_status NOT NULL DEFAULT 'created'` | no |
| `created_by_employee_id` | `bigint NOT NULL` | no |
| `performed_by_employee_id` | `bigint` | yes |
| `started_at` | `timestamptz` | yes |
| `completed_at` | `timestamptz` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_inventory_counts PRIMARY KEY (inventory_count_id)`
- `CONSTRAINT fk_inventory_counts_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_counts_performed_by_employee FOREIGN KEY (performed_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_counts_count_number UNIQUE (count_number)`
- `CONSTRAINT ck_inventory_counts_number_not_blank CHECK (btrim(count_number) <> '')`
- `CONSTRAINT ck_inventory_counts_started_at CHECK (started_at IS NULL OR started_at >= created_at)`
- `CONSTRAINT ck_inventory_counts_completed_at CHECK (completed_at IS NULL OR (completed_at >= created_at AND (started_at IS NULL OR completed_at >= started_at)))`

## inventory_count_items

| Column | SQL definition | Nullable |
|---|---|---|
| `inventory_count_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `inventory_count_id` | `bigint NOT NULL` | no |
| `product_id` | `bigint NOT NULL` | no |
| `location_id` | `bigint NOT NULL` | no |
| `expected_quantity` | `integer NOT NULL` | no |
| `actual_quantity` | `integer` | yes |
| `difference_quantity` | `integer GENERATED ALWAYS AS (actual_quantity - expected_quantity) STORED` | yes |

Constraints:

- `CONSTRAINT pk_inventory_count_items PRIMARY KEY (inventory_count_item_id)`
- `CONSTRAINT fk_inventory_count_items_count FOREIGN KEY (inventory_count_id) REFERENCES inventory_counts (inventory_count_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_count_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_count_items_location FOREIGN KEY (location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_count_items_count_location UNIQUE (inventory_count_id, location_id)`
- `CONSTRAINT ck_inventory_count_items_expected_nonnegative CHECK (expected_quantity >= 0)`
- `CONSTRAINT ck_inventory_count_items_actual_nonnegative CHECK (actual_quantity IS NULL OR actual_quantity >= 0)`

## picking_tasks

| Column | SQL definition | Nullable |
|---|---|---|
| `picking_task_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `shipment_item_id` | `bigint NOT NULL` | no |
| `source_location_id` | `bigint NOT NULL` | no |
| `target_location_id` | `bigint NOT NULL` | no |
| `assigned_employee_id` | `bigint` | yes |
| `status` | `picking_status NOT NULL DEFAULT 'created'` | no |
| `requested_quantity` | `integer NOT NULL` | no |
| `picked_quantity` | `integer NOT NULL DEFAULT 0` | no |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |
| `started_at` | `timestamptz` | yes |
| `completed_at` | `timestamptz` | yes |

Constraints:

- `CONSTRAINT pk_picking_tasks PRIMARY KEY (picking_task_id)`
- `CONSTRAINT fk_picking_tasks_shipment_item FOREIGN KEY (shipment_item_id) REFERENCES shipment_items (shipment_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_picking_tasks_source_location FOREIGN KEY (source_location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_picking_tasks_target_location FOREIGN KEY (target_location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_picking_tasks_assigned_employee FOREIGN KEY (assigned_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_picking_tasks_item_route UNIQUE (shipment_item_id, source_location_id, target_location_id)`
- `CONSTRAINT ck_picking_tasks_locations_different CHECK (source_location_id <> target_location_id)`
- `CONSTRAINT ck_picking_tasks_requested_positive CHECK (requested_quantity > 0)`
- `CONSTRAINT ck_picking_tasks_picked_valid CHECK (picked_quantity >= 0 AND picked_quantity <= requested_quantity)`
- `CONSTRAINT ck_picking_tasks_started_at CHECK (started_at IS NULL OR started_at >= created_at)`
- `CONSTRAINT ck_picking_tasks_completed_at CHECK (completed_at IS NULL OR (completed_at >= created_at AND (started_at IS NULL OR completed_at >= started_at)))`

## inventory

| Column | SQL definition | Nullable |
|---|---|---|
| `product_id` | `bigint NOT NULL` | no |
| `location_id` | `bigint NOT NULL` | no |
| `quantity` | `integer NOT NULL` | no |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_inventory PRIMARY KEY (product_id, location_id)`
- `CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_location FOREIGN KEY (location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_location UNIQUE (location_id)`
- `CONSTRAINT ck_inventory_quantity_positive CHECK (quantity > 0)`

## stock_movements

| Column | SQL definition | Nullable |
|---|---|---|
| `movement_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `movement_type` | `movement_type NOT NULL` | no |
| `product_id` | `bigint NOT NULL` | no |
| `quantity` | `integer NOT NULL` | no |
| `from_location_id` | `bigint` | yes |
| `to_location_id` | `bigint` | yes |
| `performed_by_employee_id` | `bigint NOT NULL` | no |
| `receipt_item_id` | `bigint` | yes |
| `shipment_item_id` | `bigint` | yes |
| `picking_task_id` | `bigint` | yes |
| `inventory_count_item_id` | `bigint` | yes |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_stock_movements PRIMARY KEY (movement_id)`
- `CONSTRAINT fk_stock_movements_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_from_location FOREIGN KEY (from_location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_to_location FOREIGN KEY (to_location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_employee FOREIGN KEY (performed_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_receipt_item FOREIGN KEY (receipt_item_id) REFERENCES receipt_items (receipt_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_shipment_item FOREIGN KEY (shipment_item_id) REFERENCES shipment_items (shipment_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_picking_task FOREIGN KEY (picking_task_id) REFERENCES picking_tasks (picking_task_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_stock_movements_inventory_count_item FOREIGN KEY (inventory_count_item_id) REFERENCES inventory_count_items (inventory_count_item_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT ck_stock_movements_quantity_positive CHECK (quantity > 0)`
- `CONSTRAINT ck_stock_movements_locations_different CHECK (from_location_id IS NULL OR to_location_id IS NULL OR from_location_id <> to_location_id)`
- `CONSTRAINT ck_stock_movements_route CHECK ((movement_type IN ('receipt', 'return_receipt', 'inventory_surplus') AND from_location_id IS NULL AND to_location_id IS NOT NULL) OR (movement_type IN ('shipment', 'inventory_shortage') AND from_location_id IS NOT NULL AND to_location_id IS NULL) OR (movement_type IN ('transfer', 'damage_transfer', 'picking') AND from_location_id IS NOT NULL AND to_location_id IS NOT NULL))`
- `CONSTRAINT ck_stock_movements_document_source CHECK ((movement_type IN ('receipt', 'return_receipt') AND receipt_item_id IS NOT NULL AND num_nonnulls(receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type = 'shipment' AND shipment_item_id IS NOT NULL AND num_nonnulls(receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type = 'picking' AND picking_task_id IS NOT NULL AND num_nonnulls(receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type IN ('inventory_surplus', 'inventory_shortage') AND inventory_count_item_id IS NOT NULL AND num_nonnulls(receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 1) OR (movement_type IN ('transfer', 'damage_transfer') AND num_nonnulls(receipt_item_id, shipment_item_id, picking_task_id, inventory_count_item_id) = 0))`

## audit_logs

| Column | SQL definition | Nullable |
|---|---|---|
| `audit_id` | `bigint GENERATED ALWAYS AS IDENTITY` | no |
| `employee_id` | `bigint` | yes |
| `table_name` | `text NOT NULL` | no |
| `record_pk` | `jsonb NOT NULL` | no |
| `operation` | `audit_operation NOT NULL` | no |
| `old_data` | `jsonb` | yes |
| `new_data` | `jsonb` | yes |
| `database_user` | `text NOT NULL DEFAULT CURRENT_USER` | no |
| `changed_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | no |

Constraints:

- `CONSTRAINT pk_audit_logs PRIMARY KEY (audit_id)`
- `CONSTRAINT fk_audit_logs_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT ck_audit_logs_table_name_not_blank CHECK (btrim(table_name) <> '')`
- `CONSTRAINT ck_audit_logs_record_pk_object CHECK (jsonb_typeof(record_pk) = 'object')`
- `CONSTRAINT ck_audit_logs_row_images CHECK ((operation = 'insert' AND old_data IS NULL AND new_data IS NOT NULL) OR (operation = 'update' AND old_data IS NOT NULL AND new_data IS NOT NULL) OR (operation = 'delete' AND old_data IS NOT NULL AND new_data IS NULL))`

## Indexes and cross-table checks

Primary keys and UNIQUE constraints create their own indexes. Migration 04
adds indexes for active catalog filters, queues and movement history. A partial
unique index on warehouse_locations(location_kind), restricted to warehouse,
enforces one root.

Posting procedures check cell purpose, capacity and stock availability.
Document triggers check seller ownership and transitions. Inventory counts have
storage tables but no posting or finalization rules.

updated_at is not automatically maintained on every table. Posting procedures
update inventory timestamps; guards update receipt/shipment headers. Reference
edits require an explicit timestamp assignment.
