-- Наполнение БД для демонстрации прироста от индексов (PostgreSQL)
-- Выполнять после lab2/ddl.sql и lab2/dml.sql.
-- Создает много записей, чтобы EXPLAIN ANALYZE показывал разницу.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_user_to_add  int := 5000;   -- кол-во дополнительных пользователей
    v_order_to_add int := 50000;  -- кол-во заказов (будут сгенерированы случайно)
    v_user_count   int;
    v_tt_count     int;
BEGIN
    -- Добавляем дополнительные события и типы билетов для разнообразия
    INSERT INTO event (organizer_id, title, description, location, start_time, end_time)
    SELECT id, 'Data Days', 'Конференция о данных', 'Москва',
           now() + interval '20 days', now() + interval '20 days 6 hours'
    FROM organizer 
    WHERE name = 'MTS True Tech'
      AND NOT EXISTS (SELECT 1 FROM event WHERE title = 'Data Days');

    INSERT INTO event (organizer_id, title, description, location, start_time, end_time)
    SELECT id, 'Music Bridge', 'Фестиваль живой музыки', 'СПб',
           now() + interval '40 days', now() + interval '40 days 5 hours'
    FROM organizer 
    WHERE name = 'Zvuchok'
      AND NOT EXISTS (SELECT 1 FROM event WHERE title = 'Music Bridge');

    INSERT INTO event (organizer_id, title, description, location, start_time, end_time)
    SELECT id, 'Cloud Expo', 'Большая выставка облачных решений', 'Новосибирск',
           now() + interval '60 days', now() + interval '60 days 8 hours'
    FROM organizer 
    WHERE name = 'MTS True Tech'
      AND NOT EXISTS (SELECT 1 FROM event WHERE title = 'Cloud Expo');

    -- Типы билетов для новых событий (добавятся, если их ещё нет)
    INSERT INTO ticket_type (event_id, name, price, quantity_total)
    SELECT e.id, tt.name, tt.price, tt.qty
    FROM (
        VALUES
            ('Data Days',    'Standard', 1200.00, 800),
            ('Data Days',    'VIP',      3200.00, 200),
            ('Music Bridge', 'Standard', 1800.00, 900),
            ('Music Bridge', 'Fan',      2600.00, 300),
            ('Cloud Expo',   'Standard', 1500.00, 700),
            ('Cloud Expo',   'Premium',  2800.00, 250)
    ) AS tt(event_title, name, price, qty)
    JOIN event e ON e.title = tt.event_title
    WHERE NOT EXISTS (
        SELECT 1 FROM ticket_type tt_existing
        WHERE tt_existing.event_id = e.id AND tt_existing.name = tt.name
    );

    -- Массовое добавление пользователей
    INSERT INTO users (name, email, password_hash)
    SELECT 'LoadUser-' || g,
           'loaduser' || g || '@example.com',
           'hash' || g
    FROM generate_series(1, v_user_to_add) g;

    SELECT COUNT(*) INTO v_user_count FROM users;
    SELECT COUNT(*) INTO v_tt_count FROM ticket_type;

    -- Массовое добавление заказов (случайные пользователи, даты и статусы)
    INSERT INTO orders (user_id, order_date, status)
    SELECT
        (SELECT id FROM users OFFSET floor(random() * v_user_count) LIMIT 1),
        now() - (random() * 90 || ' days')::interval,
        (ARRAY['pending','completed','cancelled'])[ceil(random()*3)]
    FROM generate_series(1, v_order_to_add);

    -- Позиции заказов: для большинства заказов создаем по 1-3 позиции
    INSERT INTO order_item (order_id, ticket_type_id, quantity)
    SELECT
        o.id,
        (SELECT id FROM ticket_type OFFSET floor(random() * v_tt_count) LIMIT 1),
        1 + floor(random()*3)::int
    FROM orders o
    WHERE o.order_date >= now() - interval '90 days'; -- только новые сгенерированные

    -- Обновляем проданные количества, чтобы отражали новые позиции
    UPDATE ticket_type tt
    SET quantity_sold = GREATEST(
        0,
        (SELECT COALESCE(SUM(oi.quantity), 0) FROM order_item oi WHERE oi.ticket_type_id = tt.id)
    );
END $$;

-- После выполнения запускайте EXPLAIN ANALYZE из lab4.sql до/после индексов.

