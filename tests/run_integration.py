"""Устанавливает и проверяет схему склада в пустой базе PostgreSQL."""
import os
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = (
    '01_types.sql',
    '02_reference_tables.sql',
    '03_operational_tables.sql',
    '04_indexes.sql',
    '05_stock_transfer.sql',
    '06_operations.sql',
    '07_document_rules.sql',
    '08_analytics.sql',
    '11_demo_generator.sql',
)


def run_script(connection, path):
    connection.execute(path.read_text(encoding='utf-8'))
    print(f'Passed: {path.relative_to(ROOT)}', flush=True)


def main():
    database_url = os.environ.get('TEST_DATABASE_URL')
    if not database_url:
        raise SystemExit('Set TEST_DATABASE_URL to an empty test database')

    with psycopg.connect(database_url, autocommit=True) as connection:
        if connection.execute("SELECT to_regnamespace('warehouse')").fetchone()[0]:
            raise SystemExit('warehouse schema already exists; use an empty database')

        for name in MIGRATIONS:
            run_script(connection, ROOT / 'sql' / name)
        run_script(connection, ROOT / 'examples/demo.sql')

        for name in ('01_schema_smoke_test.sql', '02_indexes_test.sql', '03_stock_transfer_test.sql'):
            run_script(connection, ROOT / 'tests' / name)

        connection.execute('CALL warehouse.generate_demo_data(20, 0.42)')
        for name in ('04_workflow_test.sql', '05_edge_cases_test.sql'):
            run_script(connection, ROOT / 'tests' / name)
        run_script(connection, ROOT / 'examples/demo.sql')
        run_script(connection, ROOT / 'sql/09_analytical_queries.sql')

    print('Integration tests passed')


if __name__ == '__main__':
    main()
