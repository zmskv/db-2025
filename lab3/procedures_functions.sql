-- Процедуры и функции для лабораторной работы 3

-- 1. Функция: Проверка доступности билетов
CREATE OR REPLACE FUNCTION check_ticket_availability(
    p_ticket_type_id UUID,
    p_quantity INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_available INT;
BEGIN
    SELECT (quantity_total - quantity_sold) INTO v_available
    FROM ticket_type
    WHERE id = p_ticket_type_id;
    
    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Тип билета с ID % не найден', p_ticket_type_id;
    END IF;
    
    RETURN v_available >= p_quantity;
END;
$$ LANGUAGE plpgsql;

-- 2. Процедура: Создание заказа с проверкой доступности билетов
CREATE OR REPLACE PROCEDURE create_order_with_items(
    p_user_id UUID,
    p_ticket_type_id UUID,
    p_quantity INT,
    OUT p_order_id UUID,
    OUT p_message TEXT
) AS $$
DECLARE
    v_available INT;
    v_ticket_name VARCHAR(100);
    v_event_id UUID;
    v_event_title VARCHAR(255);
BEGIN
    -- Проверка существования пользователя
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', p_user_id;
    END IF;
    
    -- Проверка существования типа билета
    SELECT name, event_id INTO v_ticket_name, v_event_id
    FROM ticket_type
    WHERE id = p_ticket_type_id;
    
    IF v_ticket_name IS NULL THEN
        RAISE EXCEPTION 'Тип билета с ID % не найден', p_ticket_type_id;
    END IF;
    
    -- Проверка доступности билетов
    SELECT (quantity_total - quantity_sold) INTO v_available
    FROM ticket_type
    WHERE id = p_ticket_type_id;
    
    IF v_available < p_quantity THEN
        RAISE EXCEPTION 'Недостаточно билетов. Доступно: %, запрошено: %', v_available, p_quantity;
    END IF;
    
    -- Создание заказа
    INSERT INTO orders (user_id, status)
    VALUES (p_user_id, 'pending')
    RETURNING id INTO p_order_id;
    
    -- Добавление позиции заказа (триггер автоматически обновит quantity_sold)
    INSERT INTO order_item (order_id, ticket_type_id, quantity)
    VALUES (p_order_id, p_ticket_type_id, p_quantity);
    
    SELECT title INTO v_event_title
    FROM event
    WHERE id = v_event_id;
    
    p_message := format('Заказ успешно создан. Билеты: %s, количество: %s, мероприятие: %s', 
                        v_ticket_name, p_quantity, v_event_title);
    
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Нарушение уникальности данных';
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Нарушение внешнего ключа. Проверьте корректность ID пользователя или типа билета';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка при создании заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- 3. Функция: Получение статистики по пользователю
CREATE OR REPLACE FUNCTION get_user_order_stats(
    p_user_id UUID
) RETURNS TABLE(
    total_orders INT,
    completed_orders INT,
    pending_orders INT,
    total_tickets INT,
    total_spent DECIMAL(10,2)
) AS $$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    -- Проверка существования пользователя
    SELECT EXISTS(SELECT 1 FROM users WHERE id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', p_user_id;
    END IF;
    
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT o.id)::INT AS total_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'completed' THEN o.id END)::INT AS completed_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'pending' THEN o.id END)::INT AS pending_orders,
        COALESCE(SUM(oi.quantity), 0)::INT AS total_tickets,
        COALESCE(SUM(oi.quantity * tt.price), 0)::DECIMAL(10,2) AS total_spent
    FROM orders o
    LEFT JOIN order_item oi ON o.id = oi.order_id
    LEFT JOIN ticket_type tt ON oi.ticket_type_id = tt.id
    WHERE o.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Процедура: Отмена заказа с возвратом билетов
CREATE OR REPLACE PROCEDURE cancel_order(
    p_order_id UUID,
    OUT p_message TEXT
) AS $$
DECLARE
    v_order_status VARCHAR(50);
    v_ticket_type_id UUID;
    v_quantity INT;
BEGIN
    -- Проверка существования заказа
    SELECT status INTO v_order_status
    FROM orders
    WHERE id = p_order_id;
    
    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Заказ с ID % не найден', p_order_id;
    END IF;
    
    IF v_order_status = 'cancelled' THEN
        RAISE EXCEPTION 'Заказ уже отменен';
    END IF;
    
    -- Возврат билетов для каждой позиции заказа
    FOR v_ticket_type_id, v_quantity IN
        SELECT ticket_type_id, quantity
        FROM order_item
        WHERE order_id = p_order_id
    LOOP
        UPDATE ticket_type
        SET quantity_sold = quantity_sold - v_quantity
        WHERE id = v_ticket_type_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Ошибка при возврате билетов типа %', v_ticket_type_id;
        END IF;
    END LOOP;
    
    -- Отмена заказа
    UPDATE orders
    SET status = 'cancelled'
    WHERE id = p_order_id;
    
    p_message := format('Заказ %s успешно отменен. Билеты возвращены', p_order_id);
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка при отмене заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

