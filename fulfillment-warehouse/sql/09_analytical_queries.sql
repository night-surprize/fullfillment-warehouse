SET search_path = warehouse, public;

-- Остатки продавцов и их место по занимаемому объему.
WITH balances AS (
    SELECT
        seller_id,
        seller_name,
        SUM(quantity) AS units,
        SUM(volume_m3) AS volume_m3
    FROM
        v_inventory
    GROUP BY
        seller_id,
        seller_name
)
SELECT
    *,
    DENSE_RANK() OVER (ORDER BY volume_m3 DESC) AS volume_rank
FROM
    balances;

-- Созданные отгрузки по дням, включая дни без документов, и среднее за семь дней.
WITH days AS (
    SELECT
        generate_series(CURRENT_DATE -29, CURRENT_DATE, INTERVAL '1 day')::DATE AS day
),
counts AS (
    SELECT
        created_at::DATE AS day,
        COUNT(*) AS documents
    FROM
        shipments
    GROUP BY
        1
)
SELECT
    d.day,
    COALESCE(c.documents, 0) AS documents,
    AVG(COALESCE(c.documents, 0)) OVER (ORDER BY d.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d,
    COALESCE(c.documents, 0) - LAG(COALESCE(c.documents, 0)) OVER (ORDER BY d.day) AS change_from_previous_day
FROM
    days d
    LEFT JOIN counts c USING (day)
ORDER BY
    day;

-- Полные адреса ячеек с защитой от циклов в иерархии.
WITH RECURSIVE paths AS (
    SELECT
        location_id,
        parent_location_id,
        location_code::TEXT AS path,
        ARRAY[location_id] AS visited
    FROM
        warehouse_locations
    WHERE
        parent_location_id IS NULL
    UNION ALL
    SELECT
        c.location_id,
        c.parent_location_id,
        p.path || ' / ' || c.location_code,
        p.visited || c.location_id
    FROM
        paths p
        JOIN warehouse_locations c ON c.parent_location_id = p.location_id
    WHERE
        NOT c.location_id = ANY (p.visited)
)
SELECT
    *
FROM
    paths
ORDER BY
    path;

-- Расхождения приемки и доля брака по продавцам.
SELECT
    seller_id,
    SUM(received_quantity) AS units,
    SUM(discrepancy_quantity) AS discrepancy,
    ROUND(100.0 * SUM(damaged_quantity) / NULLIF (SUM(received_quantity), 0), 2) AS damaged_pct,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY processing_minutes) AS p95_processing_minutes
FROM
    v_receipt_performance
GROUP BY
    seller_id
ORDER BY
    damaged_pct DESC;

-- Загрузка ячеек, включая пустые.
SELECT
    l.location_id,
    l.location_code,
    COALESCE(v.quantity, 0) AS quantity,
    COALESCE(v.weight_utilization_pct, 0) AS weight_pct,
    COALESCE(v.volume_utilization_pct, 0) AS volume_pct
FROM
    warehouse_locations l
    LEFT JOIN v_inventory v USING (location_id)
WHERE
    l.location_kind = 'cell'
    AND l.deleted_at IS NULL
ORDER BY
    volume_pct DESC;

-- Если остатки менялись через процедуры, результат должен быть пустым.
SELECT
    *
FROM
    v_inventory_reconciliation;
