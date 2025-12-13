-- Подготовка расширений (для триграммного индекса).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Поиск заказов по диапазону дат (план до индекса):
EXPLAIN ANALYZE
SELECT id, user_id, order_date, status
FROM orders
WHERE order_date BETWEEN '2025-05-01' AND '2025-06-30'
ORDER BY order_date DESC;

/*
Sort  (cost=1257.83..1258.28 rows=181 width=49) (actual time=4.995..4.996 rows=3.00 loops=1)
  Sort Key: order_date DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=504
  ->  Seq Scan on orders  (cost=0.00..1251.05 rows=181 width=49) (actual time=0.020..4.972 rows=3.00 loops=1)
        Filter: ((order_date >= '2025-05-01 00:00:00'::timestamp without time zone) AND (order_date <= '2025-06-30 00:00:00'::timestamp without time zone))
        Rows Removed by Filter: 50000
        Buffers: shared hit=501
Planning:
  Buffers: shared hit=95
Planning Time: 0.526 ms
Execution Time: 5.028 ms
*/

-- Индекс для ускорения диапазонов и сортировки по дате.
CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON orders (order_date DESC);

-- После индекса

/*
Sort  (cost=380.33..380.80 rows=186 width=49) (actual time=0.030..0.031 rows=3.00 loops=1)
  Sort Key: order_date DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=3
  ->  Bitmap Heap Scan on orders  (cost=6.20..373.32 rows=186 width=49) (actual time=0.019..0.020 rows=3.00 loops=1)
        Recheck Cond: ((order_date >= '2025-05-01 00:00:00'::timestamp without time zone) AND (order_date <= '2025-06-30 00:00:00'::timestamp without time zone))
        Heap Blocks: exact=1
        Buffers: shared hit=3
        ->  Bitmap Index Scan on idx_orders_order_date  (cost=0.00..6.15 rows=186 width=0) (actual time=0.005..0.005 rows=3.00 loops=1)
              Index Cond: ((order_date >= '2025-05-01 00:00:00'::timestamp without time zone) AND (order_date <= '2025-06-30 00:00:00'::timestamp without time zone))
              Index Searches: 1
              Buffers: shared hit=2
Planning:
  Buffers: shared hit=19 read=3
Planning Time: 0.652 ms
Execution Time: 0.067 ms
*/

-- Фильтрация и сортировка по текстовым полям (префиксный LIKE):
EXPLAIN ANALYZE
SELECT title, location, start_time
FROM event
WHERE lower(title) LIKE 'mts%'
ORDER BY start_time DESC;

/*
Sort  (cost=17.06..17.07 rows=2 width=72) (actual time=0.145..0.146 rows=1.00 loops=1)
  Sort Key: start_time DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1
  ->  Seq Scan on event  (cost=0.00..17.05 rows=2 width=72) (actual time=0.139..0.141 rows=1.00 loops=1)
        Filter: (lower(title) ~~ 'mts%'::text)
        Rows Removed by Filter: 4
        Buffers: shared hit=1
Planning:
  Buffers: shared hit=33
Planning Time: 0.116 ms
Execution Time: 0.156 ms
*/

-- Индекс под lower(title) + сортировку по дате начала.
CREATE INDEX IF NOT EXISTS idx_event_title_start
    ON event (lower(title) text_pattern_ops, start_time DESC);
/*
Sort  (cost=1.08..1.09 rows=1 width=72) (actual time=0.048..0.049 rows=1.00 loops=1)
  Sort Key: start_time DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1
  ->  Seq Scan on event  (cost=0.00..1.07 rows=1 width=72) (actual time=0.033..0.036 rows=1.00 loops=1)
        Filter: (lower(title) ~~ 'mts%'::text)
        Rows Removed by Filter: 4
        Buffers: shared hit=1
Planning:
  Buffers: shared hit=48 read=1
Planning Time: 0.569 ms
Execution Time: 0.073 ms
*/

-- Поиск по подстроке (ILIKE '%...%') по описанию события:
EXPLAIN ANALYZE
SELECT id, title, description
FROM event
WHERE description ILIKE '%фестив%';

/*
Seq Scan on event  (cost=0.00..1.06 rows=1 width=80) (actual time=0.067..0.074 rows=2.00 loops=1)
  Filter: (description ~~* '%фестив%'::text)
  Rows Removed by Filter: 3
  Buffers: shared hit=1
Planning Time: 0.098 ms
Execution Time: 0.094 ms
*/

-- Триграммный GIN индекс для подстрочного поиска.
CREATE INDEX IF NOT EXISTS idx_event_description_trgm
    ON event USING gin (description gin_trgm_ops);


/*
Seq Scan on event  (cost=0.00..1.06 rows=1 width=80) (actual time=0.021..0.028 rows=2.00 loops=1)
  Filter: (description ~~* '%фестив%'::text)
  Rows Removed by Filter: 3
  Buffers: shared hit=1
Planning:
  Buffers: shared hit=25
Planning Time: 0.277 ms
Execution Time: 0.048 ms 
*/

-- Фильтрация билетов по названию и сортировка по цене:
EXPLAIN ANALYZE
SELECT name, price, quantity_total, quantity_sold
FROM ticket_type
WHERE lower(name) LIKE 'vip%'
ORDER BY price DESC;

CREATE INDEX IF NOT EXISTS idx_ticket_type_name_price
    ON ticket_type (lower(name) text_pattern_ops, price DESC);

/*
Sort  (cost=20.54..20.55 rows=4 width=56) (actual time=0.087..0.088 rows=2.00 loops=1)
  Sort Key: price DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=4
  ->  Seq Scan on ticket_type  (cost=0.00..20.50 rows=4 width=56) (actual time=0.025..0.028 rows=2.00 loops=1)
        Filter: (lower(name) ~~ 'vip%'::text)
        Rows Removed by Filter: 8
        Buffers: shared hit=1
Planning:
  Buffers: shared hit=45
Planning Time: 0.217 ms
Execution Time: 0.108 ms
*/

-- Дополнительные вспомогательные индексы для join/агрегаций:
CREATE INDEX IF NOT EXISTS idx_order_item_order ON order_item (order_id);
CREATE INDEX IF NOT EXISTS idx_order_item_ticket ON order_item (ticket_type_id);
CREATE INDEX IF NOT EXISTS idx_ticket_type_event ON ticket_type (event_id);

-- Cумма и количество билетов по пользователю.
EXPLAIN ANALYZE
SELECT u.name,
       COUNT(DISTINCT o.id) AS orders_cnt,
       SUM(oi.quantity) AS tickets_cnt,
       SUM(oi.quantity * tt.price) AS revenue
FROM users u
JOIN orders o          ON o.user_id = u.id
JOIN order_item oi     ON oi.order_id = o.id
JOIN ticket_type tt    ON tt.id = oi.ticket_type_id
WHERE o.status = 'completed'
GROUP BY u.name
ORDER BY revenue DESC;

/*
Sort  (cost=4607.22..4619.73 rows=5002 width=61) (actual time=22.084..22.092 rows=3.00 loops=1)
  Sort Key: (sum(((oi.quantity)::numeric * tt.price))) DESC
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1084
  ->  GroupAggregate  (cost=3942.86..4299.89 rows=5002 width=61) (actual time=22.068..22.077 rows=3.00 loops=1)
        Group Key: u.name
        Buffers: shared hit=1081
        ->  Sort  (cost=3942.86..3984.93 rows=16829 width=49) (actual time=19.872..20.353 rows=16652.00 loops=1)
              Sort Key: u.name, o.id
              Sort Method: quicksort  Memory: 1809kB
              Buffers: shared hit=1081
              ->  Hash Join  (cost=1507.17..2761.58 rows=16829 width=49) (actual time=5.541..13.567 rows=16652.00 loops=1)
                    Hash Cond: (oi.ticket_type_id = tt.id)
                    Buffers: shared hit=1075
                    ->  Hash Join  (cost=1505.94..2697.45 rows=16829 width=49) (actual time=5.520..12.354 rows=16652.00 loops=1)
                          Hash Cond: (o.user_id = u.id)
                          Buffers: shared hit=1074
                          ->  Hash Join  (cost=1336.40..2483.70 rows=16829 width=52) (actual time=4.332..9.897 rows=16652.00 loops=1)
                                Hash Cond: (oi.order_id = o.id)
                                Buffers: shared hit=1017
                                ->  Seq Scan on order_item oi  (cost=0.00..1016.03 rows=50003 width=36) (actual time=0.004..1.425 rows=50003.00 loops=1)
                                      Buffers: shared hit=516
                                ->  Hash  (cost=1126.04..1126.04 rows=16829 width=32) (actual time=4.284..4.284 rows=16652.00 loops=1)
                                      Buckets: 32768  Batches: 1  Memory Usage: 1297kB
                                      Buffers: shared hit=501
                                      ->  Seq Scan on orders o  (cost=0.00..1126.04 rows=16829 width=32) (actual time=0.004..2.764 rows=16652.00 loops=1)
                                            Filter: (status = 'completed'::text)
                                            Rows Removed by Filter: 33351
                                            Buffers: shared hit=501
                          ->  Hash  (cost=107.02..107.02 rows=5002 width=29) (actual time=1.171..1.175 rows=5002.00 loops=1)
                                Buckets: 8192  Batches: 1  Memory Usage: 366kB
                                Buffers: shared hit=57
                                ->  Seq Scan on users u  (cost=0.00..107.02 rows=5002 width=29) (actual time=0.005..0.513 rows=5002.00 loops=1)
                                      Buffers: shared hit=57
                    ->  Hash  (cost=1.10..1.10 rows=10 width=32) (actual time=0.014..0.014 rows=10.00 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          Buffers: shared hit=1
                          ->  Seq Scan on ticket_type tt  (cost=0.00..1.10 rows=10 width=32) (actual time=0.009..0.010 rows=10.00 loops=1)
                                Buffers: shared hit=1
Planning:
  Buffers: shared hit=298 read=6 dirtied=4
Planning Time: 0.881 ms
Execution Time: 22.227 ms
*/

-- Non-repeatable read:
-- T1: 
BEGIN;
SELECT quantity_sold FROM ticket_type WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');
/*


*/
-- T2
BEGIN;
UPDATE ticket_type SET quantity_sold = quantity_sold + 1 WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');
COMMIT;
END;
-- T1
SELECT quantity_sold FROM ticket_type WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');

-- Фикс
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; повторить шаги — значение не изменится до окончания T1.

-- Phantom read (READ COMMITTED):
-- T1
BEGIN;
SELECT COUNT(*) FROM orders WHERE status='pending';
-- T2
BEGIN;
INSERT INTO orders (user_id, status) VALUES ((SELECT id FROM users LIMIT 1), 'pending');
COMMIT;
END;
-- T1
SELECT COUNT(*) FROM orders WHERE status='pending';
-- Число строк увеличилось (фантом).
-- Фикс: 
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; фантом не появится до завершения T1.

