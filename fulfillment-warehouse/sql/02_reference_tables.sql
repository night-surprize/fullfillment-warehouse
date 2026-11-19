BEGIN;

SET LOCAL search_path TO warehouse, public;

CREATE TABLE sellers (
    seller_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_code VARCHAR(30) NOT NULL,
    name VARCHAR(200) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_sellers PRIMARY KEY (seller_id),
    CONSTRAINT uq_sellers_seller_code UNIQUE (seller_code),
    CONSTRAINT ck_sellers_code_not_blank CHECK (BTRIM(seller_code) <> ''),
    CONSTRAINT ck_sellers_name_not_blank CHECK (BTRIM(name) <> ''),
    CONSTRAINT ck_sellers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE product_categories (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY,
    parent_category_id BIGINT,
    name VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_product_categories PRIMARY KEY (category_id),
    CONSTRAINT fk_product_categories_parent FOREIGN KEY (parent_category_id) REFERENCES
    product_categories (category_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_product_categories_parent_name UNIQUE NULLS NOT DISTINCT (parent_category_id, name),
    CONSTRAINT ck_product_categories_name_not_blank CHECK (BTRIM(name) <> ''),
    CONSTRAINT ck_product_categories_not_own_parent CHECK (parent_category_id IS NULL OR
    parent_category_id <> category_id),
    CONSTRAINT ck_product_categories_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE employees (
    employee_id BIGINT GENERATED ALWAYS AS IDENTITY,
    employee_code VARCHAR(30) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(254),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_employees PRIMARY KEY (employee_id),
    CONSTRAINT uq_employees_employee_code UNIQUE (employee_code),
    CONSTRAINT uq_employees_email UNIQUE (email),
    CONSTRAINT ck_employees_code_not_blank CHECK (BTRIM(employee_code) <> ''),
    CONSTRAINT ck_employees_name_not_blank CHECK (BTRIM(full_name) <> ''),
    CONSTRAINT ck_employees_email_not_blank CHECK (email IS NULL OR BTRIM(email) <> ''),
    CONSTRAINT ck_employees_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE sorting_centers (
    sorting_center_id BIGINT GENERATED ALWAYS AS IDENTITY,
    center_code VARCHAR(30) NOT NULL,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_sorting_centers PRIMARY KEY (sorting_center_id),
    CONSTRAINT uq_sorting_centers_center_code UNIQUE (center_code),
    CONSTRAINT ck_sorting_centers_code_not_blank CHECK (BTRIM(center_code) <> ''),
    CONSTRAINT ck_sorting_centers_name_not_blank CHECK (BTRIM(name) <> ''),
    CONSTRAINT ck_sorting_centers_address_not_blank CHECK (BTRIM(address) <> ''),
    CONSTRAINT ck_sorting_centers_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE products (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id BIGINT NOT NULL,
    category_id BIGINT NOT NULL,
    sku VARCHAR(100) NOT NULL,
    name VARCHAR(200) NOT NULL,
    unit_weight_kg NUMERIC(10, 3) NOT NULL,
    unit_volume_m3 NUMERIC(12, 6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_products PRIMARY KEY (product_id),
    CONSTRAINT fk_products_seller FOREIGN KEY (seller_id) REFERENCES sellers (seller_id) ON UPDATE
    RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories
    (category_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_products_sku UNIQUE (sku),
    CONSTRAINT ck_products_sku_not_blank CHECK (BTRIM(sku) <> ''),
    CONSTRAINT ck_products_name_not_blank CHECK (BTRIM(name) <> ''),
    CONSTRAINT ck_products_weight_positive CHECK (unit_weight_kg > 0),
    CONSTRAINT ck_products_volume_positive CHECK (unit_volume_m3 > 0),
    CONSTRAINT ck_products_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE warehouse_locations (
    location_id BIGINT GENERATED ALWAYS AS IDENTITY,
    parent_location_id BIGINT,
    location_code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    location_kind location_kind NOT NULL,
    zone_purpose zone_purpose,
    max_weight_kg NUMERIC(12, 3),
    max_volume_m3 NUMERIC(12, 6),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT pk_warehouse_locations PRIMARY KEY (location_id),
    CONSTRAINT fk_warehouse_locations_parent FOREIGN KEY (parent_location_id) REFERENCES
    warehouse_locations (location_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT uq_warehouse_locations_code UNIQUE (location_code),
    CONSTRAINT ck_warehouse_locations_code_not_blank CHECK (BTRIM(location_code) <> ''),
    CONSTRAINT ck_warehouse_locations_name_not_blank CHECK (BTRIM(name) <> ''),
    CONSTRAINT ck_warehouse_locations_not_own_parent CHECK (parent_location_id IS NULL OR
    parent_location_id <> location_id),
    CONSTRAINT ck_warehouse_locations_root CHECK ((location_kind = 'warehouse' AND
    parent_location_id IS NULL) OR (location_kind <> 'warehouse' AND parent_location_id IS
    NOT NULL)),
    CONSTRAINT ck_warehouse_locations_zone_purpose CHECK ((location_kind = 'zone' AND
    zone_purpose IS NOT NULL) OR (location_kind <> 'zone' AND zone_purpose IS NULL)),
    CONSTRAINT ck_warehouse_locations_cell_capacity CHECK ((location_kind = 'cell' AND
    max_weight_kg IS NOT NULL AND max_volume_m3 IS NOT NULL AND max_weight_kg > 0 AND
    max_volume_m3 > 0) OR (location_kind <> 'cell' AND max_weight_kg IS NULL AND
    max_volume_m3 IS NULL)),
    CONSTRAINT ck_warehouse_locations_deleted_at CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE UNIQUE INDEX uq_warehouse_locations_single_root ON warehouse_locations (location_kind)
WHERE
    location_kind = 'warehouse';

COMMIT;
