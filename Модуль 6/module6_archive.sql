CREATE TABLE IF NOT EXISTS archived_orders (
    LIKE orders INCLUDING ALL
);


DO $$
DECLARE
    v_archived_count INT;
    v_deleted_count  INT;
    v_cutoff_date    TIMESTAMP := NOW() - INTERVAL '1.5 years';
BEGIN

    -- Step 1: Copy old completed/cancelled orders to archive
    INSERT INTO archived_orders
    SELECT * FROM orders
    WHERE status IN ('доставлен', 'отменен')
      AND created_at < v_cutoff_date;

    GET DIAGNOSTICS v_archived_count = ROW_COUNT;

    -- Step 2: Delete the same records from orders
    DELETE FROM orders
    WHERE status IN ('доставлен', 'отменен')
      AND created_at < v_cutoff_date;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    -- Verify counts match
    IF v_archived_count <> v_deleted_count THEN
        RAISE EXCEPTION 'Count mismatch: archived=%, deleted=%. Rolling back!',
            v_archived_count, v_deleted_count;
    END IF;

    RAISE NOTICE 'Archiving complete. Rows archived: %, rows deleted: %',
        v_archived_count, v_deleted_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error during archiving: %. Transaction rolled back.', SQLERRM;
END;
$$;


SELECT 'orders'          AS table_name, COUNT(*) AS rows FROM orders
UNION ALL
SELECT 'archived_orders',               COUNT(*)          FROM archived_orders;
