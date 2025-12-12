-- Триггеры для лабораторной работы 3

-- 1. Триггер: Автоматическое обновление количества проданных билетов при добавлении позиции заказа
CREATE OR REPLACE FUNCTION update_ticket_quantity_on_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_available INT;
    v_quantity_total INT;
    v_quantity_sold INT;
BEGIN
    -- Получаем текущее состояние типа билета
    SELECT quantity_total, quantity_sold INTO v_quantity_total, v_quantity_sold
    FROM ticket_type
    WHERE id = NEW.ticket_type_id;
    
    IF v_quantity_total IS NULL THEN
        RAISE EXCEPTION 'Тип билета с ID % не найден', NEW.ticket_type_id;
    END IF;
    
    -- Проверка доступности билетов
    v_available := v_quantity_total - v_quantity_sold;
    
    IF v_available < NEW.quantity THEN
        RAISE EXCEPTION 'Недостаточно билетов. Доступно: %, запрошено: %', v_available, NEW.quantity;
    END IF;
    
    -- Обновление количества проданных билетов
    UPDATE ticket_type
    SET quantity_sold = quantity_sold + NEW.quantity
    WHERE id = NEW.ticket_type_id;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка триггера при добавлении позиции заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ticket_quantity_on_insert
    BEFORE INSERT ON order_item
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_quantity_on_insert();

-- 2. Триггер: Автоматическое обновление количества проданных билетов при удалении позиции заказа
CREATE OR REPLACE FUNCTION update_ticket_quantity_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Возврат билетов при удалении позиции заказа
    UPDATE ticket_type
    SET quantity_sold = quantity_sold - OLD.quantity
    WHERE id = OLD.ticket_type_id;
    
    IF NOT FOUND THEN
        RAISE WARNING 'Тип билета с ID % не найден при удалении позиции заказа', OLD.ticket_type_id;
    END IF;
    
    RETURN OLD;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка триггера при удалении позиции заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_ticket_quantity_on_delete
    AFTER DELETE ON order_item
    FOR EACH ROW
    EXECUTE FUNCTION update_ticket_quantity_on_delete();

-- 3. Триггер: Аудит изменений заказов
CREATE TABLE IF NOT EXISTS order_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    old_status TEXT,
    new_status TEXT,
    changed_at TIMESTAMP DEFAULT now(),
    changed_by TEXT DEFAULT current_user
);

CREATE OR REPLACE FUNCTION audit_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO order_audit (order_id, old_status, new_status)
        VALUES (NEW.id, OLD.status, NEW.status);
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Ошибка триггера аудита заказов: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_audit_order_changes
    AFTER UPDATE ON orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION audit_order_changes();

-- 4. Триггер: Проверка бизнес-правил при обновлении количества в позиции заказа
CREATE OR REPLACE FUNCTION validate_order_item_update()
RETURNS TRIGGER AS $$
DECLARE
    v_available INT;
    v_quantity_diff INT;
BEGIN
    -- Вычисляем разницу в количестве
    v_quantity_diff := NEW.quantity - OLD.quantity;
    
    IF v_quantity_diff = 0 THEN
        RETURN NEW;
    END IF;
    
    -- Если увеличиваем количество, проверяем доступность
    IF v_quantity_diff > 0 THEN
        -- Учитываем, что OLD.quantity уже учтено в quantity_sold
        SELECT (quantity_total - quantity_sold + OLD.quantity) INTO v_available
        FROM ticket_type
        WHERE id = NEW.ticket_type_id;
        
        IF v_available < NEW.quantity THEN
            RAISE EXCEPTION 'Недостаточно билетов для увеличения количества. Доступно: %, требуется: %', 
                            v_available, NEW.quantity;
        END IF;
        
        -- Обновляем количество проданных билетов (вычитаем старое, добавляем новое)
        UPDATE ticket_type
        SET quantity_sold = quantity_sold - OLD.quantity + NEW.quantity
        WHERE id = NEW.ticket_type_id;
    ELSE
        -- Если уменьшаем количество, возвращаем билеты
        UPDATE ticket_type
        SET quantity_sold = quantity_sold - OLD.quantity + NEW.quantity
        WHERE id = NEW.ticket_type_id;
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Ошибка триггера при обновлении позиции заказа: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_order_item_update
    BEFORE UPDATE ON order_item
    FOR EACH ROW
    WHEN (OLD.quantity IS DISTINCT FROM NEW.quantity)
    EXECUTE FUNCTION validate_order_item_update();

