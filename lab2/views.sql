-- Топ клиентов по обороту
CREATE VIEW top_customers AS
SELECT 
    u.id AS user_id,
    u.name AS user_name,
    u.email,
    COUNT(DISTINCT o.id) AS total_orders,
    SUM(oi.quantity * tt.price) AS total_spent,
    MAX(o.order_date) AS last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_item oi ON o.id = oi.order_id
LEFT JOIN ticket_type tt ON oi.ticket_type_id = tt.id
GROUP BY u.id, u.name, u.email
HAVING SUM(oi.quantity * tt.price) > 0 OR COUNT(DISTINCT o.id) = 0
ORDER BY total_spent DESC;

-- Сводка по событиям с агрегированными показателями
CREATE VIEW event_summary AS
SELECT 
    e.id AS event_id,
    e.title,
    e.location,
    e.start_time,
    o.name AS organizer_name,
    COUNT(DISTINCT tt.id) AS ticket_types_count,
    SUM(tt.quantity_total) AS total_tickets_available,
    SUM(tt.quantity_sold) AS total_tickets_sold,
    SUM(oi.quantity) AS actual_sold,
    SUM(oi.quantity * tt.price) AS total_revenue,
    AVG(tt.price) AS avg_ticket_price,
    MIN(tt.price) AS min_ticket_price,
    MAX(tt.price) AS max_ticket_price
FROM event e
INNER JOIN organizer o ON e.organizer_id = o.id
LEFT JOIN ticket_type tt ON e.id = tt.event_id
LEFT JOIN order_item oi ON tt.id = oi.ticket_type_id
GROUP BY e.id, e.title, e.location, e.start_time, o.name;

-- Активность пользователей (заказы за последний месяц)
CREATE VIEW user_activity AS
SELECT 
    u.id AS user_id,
    u.name AS user_name,
    u.email,
    COUNT(o.id) AS orders_count,
    SUM(oi.quantity) AS tickets_purchased,
    SUM(oi.quantity * tt.price) AS total_spent,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    COUNT(DISTINCT DATE(o.order_date)) AS active_days
FROM users u
LEFT JOIN orders o ON u.id = o.user_id 
    AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
LEFT JOIN order_item oi ON o.id = oi.order_id
LEFT JOIN ticket_type tt ON oi.ticket_type_id = tt.id
GROUP BY u.id, u.name, u.email
ORDER BY orders_count DESC, total_spent DESС;

