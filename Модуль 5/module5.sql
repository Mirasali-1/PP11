-- Trigger function
CREATE OR REPLACE FUNCTION calculate_final_cost()
RETURNS TRIGGER AS $$
DECLARE
    v_price_per_km NUMERIC(10,2);
BEGIN
    -- Only fire when status changes to 'доставлен'
    IF NEW.status = 'доставлен' AND (OLD.status IS DISTINCT FROM 'доставлен') THEN

        -- Find the tariff that was active on the order's creation date
        SELECT price_per_km
        INTO v_price_per_km
        FROM tariffs_history
        WHERE zone_id = NEW.zone_id
          AND start_date <= NEW.created_at::DATE
          AND (end_date IS NULL OR end_date >= NEW.created_at::DATE)
        ORDER BY start_date DESC
        LIMIT 1;

        IF v_price_per_km IS NULL THEN
            RAISE EXCEPTION 'Tariff not found for zone_id=% on date %',
                NEW.zone_id, NEW.created_at::DATE;
        END IF;

        -- Formula: final_cost = (distance_km * price_per_km) + (weight_kg * 50)
        NEW.final_cost := (NEW.distance_km * v_price_per_km) + (NEW.weight_kg * 50);

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to orders table
DROP TRIGGER IF EXISTS before_order_update ON orders;

CREATE TRIGGER before_order_update
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION calculate_final_cost();


CREATE OR REPLACE PROCEDURE block_courier(courier_id_param INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_active_orders INT;
BEGIN
    -- Check if courier has any active orders
    SELECT COUNT(*) INTO v_active_orders
    FROM orders
    WHERE courier_id = courier_id_param
      AND status = 'в пути';

    IF v_active_orders > 0 THEN
        RAISE EXCEPTION 'Нельзя заблокировать курьера, находящегося на маршруте!';
    END IF;

    -- Block the courier
    UPDATE couriers
    SET status = 'неактивен'
    WHERE id = courier_id_param;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Курьер с id=% не найден!', courier_id_param;
    END IF;

END;
$$;


-- Test 1: trigger -- change order 1 to 'доставлен', final_cost should be calculated
UPDATE orders SET status = 'доставлен' WHERE id = 1;
SELECT id, status, distance_km, weight_kg, final_cost FROM orders WHERE id = 1;

-- Test 2: block_courier -- courier 1 has no active orders, should succeed
CALL block_courier(1);
SELECT id, fio, status FROM couriers WHERE id = 1;

-- Test 3: block_courier -- courier 2 has order 'в пути', should raise exception
DO $$
BEGIN
    CALL block_courier(2);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Expected error: %', SQLERRM;
END;
$$;
