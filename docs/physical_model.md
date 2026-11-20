# Физическая модель

Все таблицы находятся в схеме warehouse. Поля и ограничения соответствуют
миграциям 01-03, бизнес-триггеры добавляются в 07. Вес указан в кг,
объем - в м3, количество - в целых единицах. NUMERIC позволяет избежать
погрешностей вычислений с плавающей точкой. TIMESTAMPTZ хранит момент времени,
который отображается в часовом поясе текущего сеанса.

## Перечисляемые типы ENUM

- `location_kind`: `warehouse`, `zone`, `aisle`, `rack`, `cell`
- `zone_purpose`: `receiving`, `storage`, `damaged`, `packing`, `shipping`
- `receipt_type`: `supplier`, `return`
- `receipt_status`: `created`, `expected`, `receiving`, `received`, `cancelled`
- `shipment_status`: `created`, `confirmed`, `picked`, `packed`, `shipped`, `cancelled`
- `picking_status`: `created`, `in_progress`, `completed`, `cancelled`
- `inventory_count_status`: `created`, `in_progress`, `completed`, `cancelled`
- `movement_type`: `receipt`, `return_receipt`, `transfer`, `damage_transfer`, `picking`, `shipment`, `inventory_surplus`, `inventory_shortage`
- `audit_operation`: `insert`, `update`, `delete`

## Продавцы (`sellers`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `seller_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `seller_code` | `varchar(30) NOT NULL` | нет |
| `name` | `varchar(200) NOT NULL` | нет |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

- `CONSTRAINT pk_sellers PRIMARY KEY (seller_id)`
- `CONSTRAINT uq_sellers_seller_code UNIQUE (seller_code)`
- `CONSTRAINT ck_sellers_code_not_blank CHECK (btrim(seller_code) <> '')`
- `CONSTRAINT ck_sellers_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_sellers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## Категории товаров (`product_categories`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `category_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `parent_category_id` | `bigint` | да |
| `name` | `varchar(150) NOT NULL` | нет |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

- `CONSTRAINT pk_product_categories PRIMARY KEY (category_id)`
- `CONSTRAINT fk_product_categories_parent FOREIGN KEY (parent_category_id) REFERENCES product_categories (category_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_product_categories_parent_name UNIQUE NULLS NOT DISTINCT (parent_category_id, name)`
- `CONSTRAINT ck_product_categories_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_product_categories_not_own_parent CHECK (parent_category_id IS NULL OR parent_category_id <> category_id)`
- `CONSTRAINT ck_product_categories_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## Сотрудники (`employees`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `employee_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `employee_code` | `varchar(30) NOT NULL` | нет |
| `full_name` | `varchar(200) NOT NULL` | нет |
| `email` | `varchar(254)` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

- `CONSTRAINT pk_employees PRIMARY KEY (employee_id)`
- `CONSTRAINT uq_employees_employee_code UNIQUE (employee_code)`
- `CONSTRAINT uq_employees_email UNIQUE (email)`
- `CONSTRAINT ck_employees_code_not_blank CHECK (btrim(employee_code) <> '')`
- `CONSTRAINT ck_employees_name_not_blank CHECK (btrim(full_name) <> '')`
- `CONSTRAINT ck_employees_email_not_blank CHECK (email IS NULL OR btrim(email) <> '')`
- `CONSTRAINT ck_employees_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## Сортировочные центры (`sorting_centers`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `sorting_center_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `center_code` | `varchar(30) NOT NULL` | нет |
| `name` | `varchar(200) NOT NULL` | нет |
| `address` | `text NOT NULL` | нет |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

- `CONSTRAINT pk_sorting_centers PRIMARY KEY (sorting_center_id)`
- `CONSTRAINT uq_sorting_centers_center_code UNIQUE (center_code)`
- `CONSTRAINT ck_sorting_centers_code_not_blank CHECK (btrim(center_code) <> '')`
- `CONSTRAINT ck_sorting_centers_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_sorting_centers_address_not_blank CHECK (btrim(address) <> '')`
- `CONSTRAINT ck_sorting_centers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## Товары (`products`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `product_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `seller_id` | `bigint NOT NULL` | нет |
| `category_id` | `bigint NOT NULL` | нет |
| `sku` | `varchar(100) NOT NULL` | нет |
| `name` | `varchar(200) NOT NULL` | нет |
| `unit_weight_kg` | `numeric(10, 3) NOT NULL` | нет |
| `unit_volume_m3` | `numeric(12, 6) NOT NULL` | нет |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

- `CONSTRAINT pk_products PRIMARY KEY (product_id)`
- `CONSTRAINT fk_products_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories (category_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_products_sku UNIQUE (sku)`
- `CONSTRAINT ck_products_sku_not_blank CHECK (btrim(sku) <> '')`
- `CONSTRAINT ck_products_name_not_blank CHECK (btrim(name) <> '')`
- `CONSTRAINT ck_products_weight_positive CHECK (unit_weight_kg > 0)`
- `CONSTRAINT ck_products_volume_positive CHECK (unit_volume_m3 > 0)`
- `CONSTRAINT ck_products_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)`

## Адреса хранения (`warehouse_locations`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `location_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `parent_location_id` | `bigint` | да |
| `location_code` | `varchar(50) NOT NULL` | нет |
| `name` | `varchar(150) NOT NULL` | нет |
| `location_kind` | `location_kind NOT NULL` | нет |
| `zone_purpose` | `zone_purpose` | да |
| `max_weight_kg` | `numeric(12, 3)` | да |
| `max_volume_m3` | `numeric(12, 6)` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `deleted_at` | `timestamptz` | да |

Ограничения:

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

## Отгрузки (`shipments`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `shipment_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `shipment_number` | `varchar(50) NOT NULL` | нет |
| `seller_id` | `bigint NOT NULL` | нет |
| `sorting_center_id` | `bigint NOT NULL` | нет |
| `created_by_employee_id` | `bigint NOT NULL` | нет |
| `status` | `shipment_status NOT NULL DEFAULT 'created'` | нет |
| `confirmed_at` | `timestamptz` | да |
| `picked_at` | `timestamptz` | да |
| `packed_at` | `timestamptz` | да |
| `shipped_at` | `timestamptz` | да |
| `cancelled_at` | `timestamptz` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

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

## Позиции отгрузок (`shipment_items`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `shipment_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `shipment_id` | `bigint NOT NULL` | нет |
| `product_id` | `bigint NOT NULL` | нет |
| `requested_quantity` | `integer NOT NULL` | нет |
| `shipped_quantity` | `integer NOT NULL DEFAULT 0` | нет |

Ограничения:

- `CONSTRAINT pk_shipment_items PRIMARY KEY (shipment_item_id)`
- `CONSTRAINT fk_shipment_items_shipment FOREIGN KEY (shipment_id) REFERENCES shipments (shipment_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_shipment_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_shipment_items_shipment_product UNIQUE (shipment_id, product_id)`
- `CONSTRAINT ck_shipment_items_requested_positive CHECK (requested_quantity > 0)`
- `CONSTRAINT ck_shipment_items_shipped_valid CHECK (shipped_quantity >= 0 AND shipped_quantity <= requested_quantity)`

## Приемки (`receipts`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `receipt_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `receipt_number` | `varchar(50) NOT NULL` | нет |
| `receipt_type` | `receipt_type NOT NULL` | нет |
| `status` | `receipt_status NOT NULL DEFAULT 'created'` | нет |
| `seller_id` | `bigint NOT NULL` | нет |
| `sorting_center_id` | `bigint` | да |
| `source_shipment_id` | `bigint` | да |
| `created_by_employee_id` | `bigint NOT NULL` | нет |
| `processed_by_employee_id` | `bigint` | да |
| `expected_at` | `timestamptz` | да |
| `started_at` | `timestamptz` | да |
| `completed_at` | `timestamptz` | да |
| `cancelled_at` | `timestamptz` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

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

## Позиции приемок (`receipt_items`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `receipt_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `receipt_id` | `bigint NOT NULL` | нет |
| `product_id` | `bigint NOT NULL` | нет |
| `expected_quantity` | `integer NOT NULL` | нет |
| `received_quantity` | `integer NOT NULL DEFAULT 0` | нет |
| `accepted_quantity` | `integer NOT NULL DEFAULT 0` | нет |
| `damaged_quantity` | `integer NOT NULL DEFAULT 0` | нет |
| `discrepancy_note` | `text` | да |

Ограничения:

- `CONSTRAINT pk_receipt_items PRIMARY KEY (receipt_item_id)`
- `CONSTRAINT fk_receipt_items_receipt FOREIGN KEY (receipt_id) REFERENCES receipts (receipt_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_receipt_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_receipt_items_receipt_product UNIQUE (receipt_id, product_id)`
- `CONSTRAINT ck_receipt_items_expected_nonnegative CHECK (expected_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_received_nonnegative CHECK (received_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_accepted_nonnegative CHECK (accepted_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_damaged_nonnegative CHECK (damaged_quantity >= 0)`
- `CONSTRAINT ck_receipt_items_distribution CHECK (accepted_quantity + damaged_quantity <= received_quantity)`

## Инвентаризации (`inventory_counts`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `inventory_count_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `count_number` | `varchar(50) NOT NULL` | нет |
| `status` | `inventory_count_status NOT NULL DEFAULT 'created'` | нет |
| `created_by_employee_id` | `bigint NOT NULL` | нет |
| `performed_by_employee_id` | `bigint` | да |
| `started_at` | `timestamptz` | да |
| `completed_at` | `timestamptz` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

- `CONSTRAINT pk_inventory_counts PRIMARY KEY (inventory_count_id)`
- `CONSTRAINT fk_inventory_counts_created_by_employee FOREIGN KEY (created_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_counts_performed_by_employee FOREIGN KEY (performed_by_employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_counts_count_number UNIQUE (count_number)`
- `CONSTRAINT ck_inventory_counts_number_not_blank CHECK (btrim(count_number) <> '')`
- `CONSTRAINT ck_inventory_counts_started_at CHECK (started_at IS NULL OR started_at >= created_at)`
- `CONSTRAINT ck_inventory_counts_completed_at CHECK (completed_at IS NULL OR (completed_at >= created_at AND (started_at IS NULL OR completed_at >= started_at)))`

## Позиции инвентаризаций (`inventory_count_items`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `inventory_count_item_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `inventory_count_id` | `bigint NOT NULL` | нет |
| `product_id` | `bigint NOT NULL` | нет |
| `location_id` | `bigint NOT NULL` | нет |
| `expected_quantity` | `integer NOT NULL` | нет |
| `actual_quantity` | `integer` | да |
| `difference_quantity` | `integer GENERATED ALWAYS AS (actual_quantity - expected_quantity) STORED` | да |

Ограничения:

- `CONSTRAINT pk_inventory_count_items PRIMARY KEY (inventory_count_item_id)`
- `CONSTRAINT fk_inventory_count_items_count FOREIGN KEY (inventory_count_id) REFERENCES inventory_counts (inventory_count_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_count_items_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_count_items_location FOREIGN KEY (location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_count_items_count_location UNIQUE (inventory_count_id, location_id)`
- `CONSTRAINT ck_inventory_count_items_expected_nonnegative CHECK (expected_quantity >= 0)`
- `CONSTRAINT ck_inventory_count_items_actual_nonnegative CHECK (actual_quantity IS NULL OR actual_quantity >= 0)`

## Задания сборки (`picking_tasks`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `picking_task_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `shipment_item_id` | `bigint NOT NULL` | нет |
| `source_location_id` | `bigint NOT NULL` | нет |
| `target_location_id` | `bigint NOT NULL` | нет |
| `assigned_employee_id` | `bigint` | да |
| `status` | `picking_status NOT NULL DEFAULT 'created'` | нет |
| `requested_quantity` | `integer NOT NULL` | нет |
| `picked_quantity` | `integer NOT NULL DEFAULT 0` | нет |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |
| `started_at` | `timestamptz` | да |
| `completed_at` | `timestamptz` | да |

Ограничения:

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

## Остатки (`inventory`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `product_id` | `bigint NOT NULL` | нет |
| `location_id` | `bigint NOT NULL` | нет |
| `quantity` | `integer NOT NULL` | нет |
| `updated_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

- `CONSTRAINT pk_inventory PRIMARY KEY (product_id, location_id)`
- `CONSTRAINT fk_inventory_product FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT fk_inventory_location FOREIGN KEY (location_id) REFERENCES warehouse_locations (location_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT uq_inventory_location UNIQUE (location_id)`
- `CONSTRAINT ck_inventory_quantity_positive CHECK (quantity > 0)`

## Движения товара (`stock_movements`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `movement_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `movement_type` | `movement_type NOT NULL` | нет |
| `product_id` | `bigint NOT NULL` | нет |
| `quantity` | `integer NOT NULL` | нет |
| `from_location_id` | `bigint` | да |
| `to_location_id` | `bigint` | да |
| `performed_by_employee_id` | `bigint NOT NULL` | нет |
| `receipt_item_id` | `bigint` | да |
| `shipment_item_id` | `bigint` | да |
| `picking_task_id` | `bigint` | да |
| `inventory_count_item_id` | `bigint` | да |
| `created_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

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

## Аудит изменений (`audit_logs`)

| Поле | Определение SQL | Допускается NULL |
|---|---|---|
| `audit_id` | `bigint GENERATED ALWAYS AS IDENTITY` | нет |
| `employee_id` | `bigint` | да |
| `table_name` | `text NOT NULL` | нет |
| `record_pk` | `jsonb NOT NULL` | нет |
| `operation` | `audit_operation NOT NULL` | нет |
| `old_data` | `jsonb` | да |
| `new_data` | `jsonb` | да |
| `database_user` | `text NOT NULL DEFAULT CURRENT_USER` | нет |
| `changed_at` | `timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP` | нет |

Ограничения:

- `CONSTRAINT pk_audit_logs PRIMARY KEY (audit_id)`
- `CONSTRAINT fk_audit_logs_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id) ON DELETE RESTRICT ON UPDATE RESTRICT`
- `CONSTRAINT ck_audit_logs_table_name_not_blank CHECK (btrim(table_name) <> '')`
- `CONSTRAINT ck_audit_logs_record_pk_object CHECK (jsonb_typeof(record_pk) = 'object')`
- `CONSTRAINT ck_audit_logs_row_images CHECK ((operation = 'insert' AND old_data IS NULL AND new_data IS NOT NULL) OR (operation = 'update' AND old_data IS NOT NULL AND new_data IS NOT NULL) OR (operation = 'delete' AND old_data IS NOT NULL AND new_data IS NULL))`

## Индексы и проверки между таблицами

Первичные ключи и ограничения UNIQUE создают собственные индексы.
Миграция 04 добавляет индексы для поиска в действующем каталоге, очередей
документов и истории движений. Частичный уникальный индекс по
warehouse_locations(location_kind) для значения warehouse гарантирует,
что корневой адрес склада будет только один.

Процедуры проведения проверяют назначение зоны, вместимость ячейки
и доступность остатка. Триггеры документов проверяют принадлежность товара
продавцу и переходы статусов. Для инвентаризации есть таблицы,
но правил проведения и завершения пока нет.

Поле updated_at обновляется автоматически не во всех таблицах.
Процедуры меняют метки времени остатков, а триггеры - документов приемки
и отгрузки. При правках справочников метку времени нужно задавать явно.
