-- Лабораторная работа №4 (PostgreSQL)
-- База: схема из lab2 (ddl.sql + dml.sql), триггеры/процедуры из lab3 при желании.
-- Скрипт содержит готовые запросы для частей:
-- 1) Индексы + сравнение планов до/после (EXPLAIN ANALYZE).
-- 2) Анализ производительности сложных запросов.
-- 3) Транзакции и аномалии параллельного доступа.

-- Подготовка расширений (для триграммного индекса).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

/* =========================================================
   1. Индексы: сначала выполняем запросы БЕЗ индексов,
   фиксируем план/время, потом создаём индекс и повторяем.
   ========================================================= */

-- 1.1 Поиск заказов по диапазону дат (план до индекса):
-- EXPLAIN ANALYZE
-- SELECT id, user_id, order_date, status
-- FROM orders
-- WHERE order_date BETWEEN '2025-05-01' AND '2025-06-30'
-- ORDER BY order_date DESC;

-- Индекс для ускорения диапазонов и сортировки по дате.
CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON orders (order_date DESC);

-- 1.2 Фильтрация и сортировка по текстовым полям (префиксный LIKE):
-- EXPLAIN ANALYZE
-- SELECT title, location, start_time
-- FROM event
-- WHERE lower(title) LIKE 'mts%'
-- ORDER BY start_time DESC;

-- Индекс под lower(title) + сортировку по дате начала.
CREATE INDEX IF NOT EXISTS idx_event_title_start
    ON event (lower(title) text_pattern_ops, start_time DESC);

-- 1.3 Поиск по подстроке (ILIKE '%...%') по описанию события:
-- EXPLAIN ANALYZE
-- SELECT id, title, description
-- FROM event
-- WHERE description ILIKE '%фестив%';

-- Триграммный GIN индекс для подстрочного поиска.
CREATE INDEX IF NOT EXISTS idx_event_description_trgm
    ON event USING gin (description gin_trgm_ops);

-- 1.4 Фильтрация билетов по названию и сортировка по цене:
-- EXPLAIN ANALYZE
-- SELECT name, price, quantity_total, quantity_sold
-- FROM ticket_type
-- WHERE lower(name) LIKE 'vip%'
-- ORDER BY price DESC;

CREATE INDEX IF NOT EXISTS idx_ticket_type_name_price
    ON ticket_type (lower(name) text_pattern_ops, price DESC);

-- После создания каждого индекса повторите соответствующий EXPLAIN ANALYZE
-- и сравните: Seq Scan -> Index Scan/Bitmap Index Scan, время выполнения.

/* =========================================================
   2. Анализ производительности с EXPLAIN
   Выполните запросы до/после индексов, изучите узлы Seq Scan,
   Hash Join, Nested Loop, Bitmap Heap/Index Scan.
   ========================================================= */

-- Дополнительные вспомогательные индексы для join/агрегаций:
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders (user_id, status);
CREATE INDEX IF NOT EXISTS idx_order_item_order ON order_item (order_id);
CREATE INDEX IF NOT EXISTS idx_order_item_ticket ON order_item (ticket_type_id);
CREATE INDEX IF NOT EXISTS idx_ticket_type_event ON ticket_type (event_id);

-- 2.1 Запрос средней сложности: сумма и количество билетов по пользователю.
-- EXPLAIN ANALYZE
-- SELECT u.name,
--        COUNT(DISTINCT o.id) AS orders_cnt,
--        SUM(oi.quantity) AS tickets_cnt,
--        SUM(oi.quantity * tt.price) AS revenue
-- FROM users u
-- JOIN orders o          ON o.user_id = u.id
-- JOIN order_item oi     ON oi.order_id = o.id
-- JOIN ticket_type tt    ON tt.id = oi.ticket_type_id
-- WHERE o.status = 'completed'
-- GROUP BY u.name
-- ORDER BY revenue DESC;
-- Сравните планы до/после индексов: Hash Join vs Nested Loop, использование idx_orders_user_status и idx_order_item_order.

-- 2.2 Запрос высокой сложности: выручка и проданные билеты по событиям.
-- EXPLAIN ANALYZE
-- SELECT e.title,
--        e.start_time,
--        SUM(oi.quantity) AS tickets_sold,
--        SUM(oi.quantity * tt.price) AS revenue
-- FROM event e
-- JOIN ticket_type tt ON tt.event_id = e.id
-- JOIN order_item oi  ON oi.ticket_type_id = tt.id
-- JOIN orders o       ON o.id = oi.order_id
-- WHERE o.order_date BETWEEN '2025-05-01' AND '2025-07-31'
--   AND o.status IN ('completed', 'pending')
-- GROUP BY e.title, e.start_time
-- HAVING SUM(oi.quantity) > 1
-- ORDER BY revenue DESC, e.start_time;
-- Анализируйте изменения планов после индексов: Bitmap Index Scan по idx_orders_order_date, Hash Join по idx_ticket_type_event/idx_order_item_ticket.

-- 2.3 Запрос с фильтром по тексту + дата (использует триграммы и даты).
-- EXPLAIN ANALYZE
-- SELECT e.title, e.location, o.order_date, u.name, oi.quantity
-- FROM event e
-- JOIN ticket_type tt ON tt.event_id = e.id
-- JOIN order_item oi  ON oi.ticket_type_id = tt.id
-- JOIN orders o       ON o.id = oi.order_id
-- JOIN users u        ON u.id = o.user_id
-- WHERE e.description ILIKE '%cloud%'
--   AND o.order_date >= '2025-05-01'
-- ORDER BY o.order_date DESC;
-- Оцените, что без idx_event_description_trgm будет Seq Scan по event.

/* =========================================================
   3. Транзакции и аномалии параллельного доступа
   Ниже — сценарии для двух сессий (T1 и T2). Выполнять в psql,
   autocommit off. В PostgreSQL READ UNCOMMITTED трактуется как
   READ COMMITTED, поэтому грязное чтение не произойдёт — это тоже
   нужно показать.
   ========================================================= */

-- 3.1 Попытка Dirty Read (не воспроизводится в Postgres):
-- Сессия T1:
--   BEGIN;
--   UPDATE ticket_type SET quantity_sold = quantity_sold + 5
--   WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest');
--   -- не коммитим
-- Сессия T2:
--   SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--   SELECT quantity_sold FROM ticket_type WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest');
-- Результат: T2 видит старое значение (грязного чтения нет).
-- Избавление: не требуется — СУБД защищает, но фиксировать транзакции своевременно.
-- Завершение: T1 ROLLBACK;

-- 3.2 Non-repeatable read (в READ COMMITTED):
-- T1: BEGIN;
-- T1: SELECT quantity_sold FROM ticket_type WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');
-- T2: BEGIN;
-- T2: UPDATE ticket_type SET quantity_sold = quantity_sold + 1 WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');
-- T2: COMMIT;
-- T1: SELECT quantity_sold FROM ticket_type WHERE name='VIP' AND event_id=(SELECT id FROM event WHERE title='Zvuchok Fest');
-- -> Значение изменилось (неповторяемое чтение).
-- Устранение: в T1 использовать REPEATABLE READ или SELECT ... FOR SHARE/UPDATE.
--   Пример: SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; повторить шаги — значение не изменится до окончания T1.

-- 3.3 Phantom read (READ COMMITTED):
-- T1: BEGIN;
-- T1: SELECT COUNT(*) FROM orders WHERE status='pending';
-- T2: BEGIN;
-- T2: INSERT INTO orders (user_id, status) VALUES ((SELECT id FROM users LIMIT 1), 'pending');
-- T2: COMMIT;
-- T1: SELECT COUNT(*) FROM orders WHERE status='pending';
-- -> Число строк увеличилось (фантом).
-- Устранение: T1 с REPEATABLE READ или SERIALIZABLE.
--   Пример: SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; фантом не появится до завершения T1.

-- 3.4 Дополнительно: продемонстрировать блокировки при SELECT ... FOR UPDATE:
-- T1: BEGIN; SELECT * FROM orders WHERE status='pending' LIMIT 1 FOR UPDATE;
-- T2: UPDATE orders SET status='completed' WHERE status='pending' LIMIT 1;
-- -> T2 ждёт блокировку; после COMMIT в T1 изменение проходит. Показывает способ устранения гонок.

-- Конец сценариев. Все операции оформлять в отчёте с выводами по планам и аномалиям.


