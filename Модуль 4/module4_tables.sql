CREATE TABLE IF NOT EXISTS couriers (
    id             SERIAL PRIMARY KEY,
    fio            VARCHAR(200) NOT NULL,
    transport_type VARCHAR(20)  NOT NULL
                       CHECK (transport_type IN ('пеший', 'авто')),
    status         VARCHAR(20)  NOT NULL DEFAULT 'свободен'
                       CHECK (status IN ('свободен', 'на заказе', 'неактивен'))
);


CREATE TABLE IF NOT EXISTS delivery_zones (
    id        SERIAL PRIMARY KEY,
    zone_name VARCHAR(50) NOT NULL UNIQUE
                  CHECK (zone_name IN ('Центр', 'Пригород', 'Межгород'))
);


CREATE TABLE IF NOT EXISTS tariffs_history (
    id           SERIAL PRIMARY KEY,
    zone_id      INTEGER     NOT NULL
                     REFERENCES delivery_zones(id) ON DELETE RESTRICT,
    price_per_km NUMERIC(10,2) NOT NULL
                     CHECK (price_per_km > 0),
    start_date   DATE        NOT NULL,
    end_date     DATE        DEFAULT NULL,
    CHECK (end_date IS NULL OR end_date > start_date)
);


CREATE TABLE IF NOT EXISTS orders (
    id           SERIAL PRIMARY KEY,
    courier_id   INTEGER     DEFAULT NULL
                     REFERENCES couriers(id) ON DELETE SET NULL,
    zone_id      INTEGER     NOT NULL
                     REFERENCES delivery_zones(id) ON DELETE RESTRICT,
    address      TEXT        NOT NULL,
    distance_km  NUMERIC(10,2) NOT NULL CHECK (distance_km > 0),
    weight_kg    NUMERIC(10,2) NOT NULL CHECK (weight_kg > 0),
    status       VARCHAR(20)  NOT NULL DEFAULT 'создан'
                     CHECK (status IN ('создан', 'в пути', 'доставлен', 'отменен')),
    created_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
    final_cost   NUMERIC(10,2) DEFAULT NULL CHECK (final_cost >= 0)
);


INSERT INTO delivery_zones (zone_name) VALUES
    ('Центр'),
    ('Пригород'),
    ('Межгород')
ON CONFLICT DO NOTHING;

INSERT INTO couriers (fio, transport_type, status) VALUES
    ('Иванов Иван Иванович',   'авто',   'свободен'),
    ('Петров Пётр Петрович',   'пеший',  'свободен'),
    ('Сидоров Алексей Юрьевич','авто',   'неактивен')
ON CONFLICT DO NOTHING;

INSERT INTO tariffs_history (zone_id, price_per_km, start_date, end_date) VALUES
    (1, 50.00,  '2024-01-01', '2024-06-30'),
    (1, 55.00,  '2024-07-01', NULL),
    (2, 40.00,  '2024-01-01', NULL),
    (3, 30.00,  '2024-01-01', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO orders (courier_id, zone_id, address, distance_km, weight_kg, status) VALUES
    (1, 1, 'ул. Ленина, 10',     5.5,  2.0,  'доставлен'),
    (2, 2, 'пр. Мира, 45',       12.3, 5.5,  'в пути'),
    (NULL, 3, 'ул. Садовая, 1',  30.0, 10.0, 'создан')
ON CONFLICT DO NOTHING;


SELECT 'couriers'        AS table_name, COUNT(*) AS rows FROM couriers
UNION ALL
SELECT 'delivery_zones',               COUNT(*)          FROM delivery_zones
UNION ALL
SELECT 'tariffs_history',              COUNT(*)          FROM tariffs_history
UNION ALL
SELECT 'orders',                       COUNT(*)          FROM orders;
