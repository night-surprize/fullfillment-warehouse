\set ON_ERROR_STOP on

DO $$
BEGIN
    IF to_regnamespace('warehouse') IS NOT NULL THEN
        RAISE EXCEPTION 'warehouse schema already exists; use a fresh database or apply only missing migrations';
    END IF;
END;
$$;

\ir ../sql/01_types.sql
\ir ../sql/02_reference_tables.sql
\ir ../sql/03_operational_tables.sql
\ir ../sql/04_indexes.sql
\ir ../sql/05_stock_transfer.sql
\ir ../sql/06_operations.sql
\ir ../sql/07_document_rules.sql
\ir ../sql/08_analytics.sql
\ir ../sql/11_demo_generator.sql

\echo Installation complete. Run examples/demo.sql or generate a dataset.
