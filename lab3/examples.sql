-- Проверка доступности билетов
SELECT check_ticket_availability(
    (SELECT id FROM ticket_type WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest')),
    10
) AS is_available;

-- Создание заказа через процедуру (успешный случай)
DO $$
DECLARE
    v_order_id UUID;
    v_message TEXT;
    v_user_id UUID;
    v_ticket_type_id UUID;
BEGIN
    -- Получаем ID пользователя и типа билета
    SELECT id INTO v_user_id FROM users WHERE name = 'Pavel';
    SELECT id INTO v_ticket_type_id FROM ticket_type 
    WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'MTS Cloud Day');
    
    -- Создаем заказ
    CALL create_order_with_items(v_user_id, v_ticket_type_id, 2, v_order_id, v_message);
    
    RAISE NOTICE 'Результат: %', v_message;
    RAISE NOTICE 'ID заказа: %', v_order_id;
END $$;

-- Попытка создать заказ с недостаточным количеством билетов (обработка ошибки)

DO $$
DECLARE
    v_order_id UUID;
    v_message TEXT;
    v_user_id UUID;
    v_ticket_type_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM users WHERE name = 'Mikhail';
    SELECT id INTO v_ticket_type_id FROM ticket_type 
    WHERE name = 'VIP' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest');
    
    -- Попытка заказать больше билетов, чем доступно
    CALL create_order_with_items(v_user_id, v_ticket_type_id, 100, v_order_id, v_message);
    
    RAISE NOTICE 'Заказ создан: %', v_message;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка перехвачена: %', SQLERRM;
END $$;

-- Попытка создать заказ с несуществующим пользователем (обработка ошибки)
DO $$
DECLARE
    v_order_id UUID;
    v_message TEXT;
    v_ticket_type_id UUID;
BEGIN
    SELECT id INTO v_ticket_type_id FROM ticket_type 
    WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest');
    
    -- Попытка создать заказ с несуществующим пользователем
    CALL create_order_with_items('00000000-0000-0000-0000-000000000000'::UUID, v_ticket_type_id, 1, v_order_id, v_message);
    
    RAISE NOTICE 'Заказ создан: %', v_message;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка перехвачена: %', SQLERRM;
END $$;

-- Получение статистики по пользователю
SELECT * FROM get_user_order_stats(
    (SELECT id FROM users WHERE name = 'Pavel')
);

-- Демонстрация работы триггера при добавлении позиции заказа

-- Проверяем текущее количество проданных билетов
SELECT name, quantity_total, quantity_sold, (quantity_total - quantity_sold) AS available
FROM ticket_type
WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'MTS Cloud Day');

-- Добавляем новую позицию заказа (триггер автоматически обновит quantity_sold)
INSERT INTO order_item (order_id, ticket_type_id, quantity)
SELECT 
    o.id,
    tt.id,
    1
FROM orders o
CROSS JOIN ticket_type tt
WHERE o.user_id = (SELECT id FROM users WHERE name = 'Pavel')
  AND o.status = 'pending'
  AND tt.name = 'Standard' 
  AND tt.event_id = (SELECT id FROM event WHERE title = 'MTS Cloud Day')
LIMIT 1;

-- Проверяем обновленное количество
SELECT name, quantity_total, quantity_sold, (quantity_total - quantity_sold) AS available
FROM ticket_type
WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'MTS Cloud Day');


-- Попытка добавить позицию заказа с недостаточным количеством (триггер блокирует)
DO $$
DECLARE
    v_order_id UUID;
    v_ticket_type_id UUID;
BEGIN
    INSERT INTO orders (user_id, status)
    SELECT id, 'pending' FROM users WHERE name = 'Mikhail'
    RETURNING id INTO v_order_id;
    
    SELECT id INTO v_ticket_type_id FROM ticket_type 
    WHERE name = 'VIP' AND event_id = (SELECT id FROM event WHERE title = 'Zvuchok Fest');
    
    INSERT INTO order_item (order_id, ticket_type_id, quantity)
    VALUES (v_order_id, v_ticket_type_id, 1000);
    
    RAISE NOTICE 'Позиция заказа добавлена';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Триггер заблокировал операцию: %', SQLERRM;
END $$;


-- Демонстрация работы триггера аудита при изменении статуса заказа

UPDATE orders
SET status = 'completed'
WHERE status = 'pending'
  AND id IN (SELECT id FROM orders WHERE status = 'pending' LIMIT 1);

SELECT 
    oa.order_id,
    oa.old_status,
    oa.new_status,
    oa.changed_at,
    u.name AS user_name
FROM order_audit oa
JOIN orders o ON oa.order_id = o.id
JOIN users u ON o.user_id = u.id
ORDER BY oa.changed_at DESC;

-- Демонстрация работы триггера при обновлении количества в позиции заказа
SELECT 
    oi.id,
    oi.quantity,
    tt.name AS ticket_name,
    tt.quantity_sold
FROM order_item oi
JOIN ticket_type tt ON oi.ticket_type_id = tt.id
WHERE oi.id IN (SELECT id FROM order_item LIMIT 1);

-- Обновляем количество (триггер автоматически обновит quantity_sold)
UPDATE order_item
SET quantity = quantity + 1
WHERE id IN (SELECT id FROM order_item LIMIT 1);

-- Проверяем обновленное состояние
SELECT 
    oi.id,
    oi.quantity,
    tt.name AS ticket_name,
    tt.quantity_sold
FROM order_item oi
JOIN ticket_type tt ON oi.ticket_type_id = tt.id
WHERE oi.id IN (SELECT id FROM order_item LIMIT 1);


-- Использование процедуры отмены заказа

DO $$
DECLARE
    v_order_id UUID;
    v_message TEXT;
    v_ticket_type_id UUID;
    v_quantity_sold_before INT;
    v_quantity_sold_after INT;
BEGIN
    -- Создаем тестовый заказ
    INSERT INTO orders (user_id, status)
    SELECT id, 'pending' FROM users WHERE name = 'Mikhail'
    RETURNING id INTO v_order_id;
    
    SELECT id INTO v_ticket_type_id FROM ticket_type 
    WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title = 'MTS Cloud Day');
    
    INSERT INTO order_item (order_id, ticket_type_id, quantity)
    VALUES (v_order_id, v_ticket_type_id, 2);
    
    -- Проверяем количество проданных билетов до отмены
    SELECT quantity_sold INTO v_quantity_sold_before
    FROM ticket_type WHERE id = v_ticket_type_id;
    
    RAISE NOTICE 'Количество проданных билетов до отмены: %', v_quantity_sold_before;
    
    -- Отменяем заказ
    CALL cancel_order(v_order_id, v_message);
    
    RAISE NOTICE 'Результат отмены: %', v_message;
    
    -- Проверяем количество проданных билетов после отмены
    SELECT quantity_sold INTO v_quantity_sold_after
    FROM ticket_type WHERE id = v_ticket_type_id;
    
    RAISE NOTICE 'Количество проданных билетов после отмены: %', v_quantity_sold_after;
END $$;

-- Попытка отменить несуществующий заказ (обработка ошибки)

DO $$
DECLARE
    v_message TEXT;
BEGIN
    CALL cancel_order('00000000-0000-0000-0000-000000000000'::UUID, v_message);
    RAISE NOTICE 'Заказ отменен: %', v_message;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка перехвачена: %', SQLERRM;
END $$;

-- емонстрация работы триггера при удалении позиции заказа

SELECT 
    tt.name,
    tt.quantity_total,
    tt.quantity_sold,
    (tt.quantity_total - tt.quantity_sold) AS available
FROM ticket_type tt
WHERE tt.id IN (SELECT ticket_type_id FROM order_item LIMIT 1);

-- Удаляем позицию заказа (триггер автоматически вернет билеты)
DELETE FROM order_item
WHERE id IN (SELECT id FROM order_item LIMIT 1);

-- Проверяем обновленное количество
SELECT 
    tt.name,
    tt.quantity_total,
    tt.quantity_sold,
    (tt.quantity_total - tt.quantity_sold) AS available
FROM ticket_type tt
WHERE tt.id IN (SELECT ticket_type_id FROM order_item LIMIT 1 OFFSET 1);






