"""Заполняет базу через процедуры приемки и отгрузки."""
import argparse
import os

import psycopg


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cycles', type=int, default=5000)
    parser.add_argument('--seed', type=float, default=0.42)
    args = parser.parse_args()
    database_url = os.environ.get('DATABASE_URL')
    if not database_url:
        parser.error('Set DATABASE_URL to the PostgreSQL connection string')
    with psycopg.connect(database_url) as connection:
        connection.execute(
            'CALL warehouse.generate_demo_data(%s::integer, %s::double precision)',
            (args.cycles, args.seed),
        )
    print(f'Generated {args.cycles} receipt/shipment cycles.')


if __name__ == '__main__':
    main()
