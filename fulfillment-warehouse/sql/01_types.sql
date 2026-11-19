BEGIN;

CREATE SCHEMA IF NOT EXISTS warehouse AUTHORIZATION CURRENT_USER;

CREATE TYPE warehouse.location_kind AS ENUM (
    'warehouse',
    'zone',
    'aisle',
    'rack',
    'cell'
);

CREATE TYPE warehouse.zone_purpose AS ENUM (
    'receiving',
    'storage',
    'damaged',
    'packing',
    'shipping'
);

CREATE TYPE warehouse.receipt_type AS ENUM (
    'supplier',
    'return'
);

CREATE TYPE warehouse.receipt_status AS ENUM (
    'created',
    'expected',
    'receiving',
    'received',
    'cancelled'
);

CREATE TYPE warehouse.shipment_status AS ENUM (
    'created',
    'confirmed',
    'picked',
    'packed',
    'shipped',
    'cancelled'
);

CREATE TYPE warehouse.picking_status AS ENUM (
    'created',
    'in_progress',
    'completed',
    'cancelled'
);

CREATE TYPE warehouse.inventory_count_status AS ENUM (
    'created',
    'in_progress',
    'completed',
    'cancelled'
);

CREATE TYPE warehouse.movement_type AS ENUM (
    'receipt',
    'return_receipt',
    'transfer',
    'damage_transfer',
    'picking',
    'shipment',
    'inventory_surplus',
    'inventory_shortage'
);

CREATE TYPE warehouse.audit_operation AS ENUM (
    'insert',
    'update',
    'delete'
);

COMMIT;
