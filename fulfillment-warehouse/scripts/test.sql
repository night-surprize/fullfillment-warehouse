\set ON_ERROR_STOP on
\ir ../tests/01_schema_smoke_test.sql
\ir ../tests/02_indexes_test.sql
\ir ../tests/03_stock_transfer_test.sql
\ir ../tests/04_workflow_test.sql
\ir ../tests/05_edge_cases_test.sql
\echo All SQL tests passed.
