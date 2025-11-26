SELECT u.name AS user_name, u.email, o.order_date, o.status
FROM users u
INNER JOIN orders o ON u.id = o.user_id
ORDER BY o.order_date DESC;

SELECT e.title, e.location, e.start_time, o.name AS organizer_name, o.email AS organizer_email
FROM event e
LEFT JOIN organizer o ON e.organizer_id = o.id
ORDER BY e.start_time;

SELECT u.name AS user_name,
       e.title AS event_title,
       tt.name AS ticket_type,
       oi.quantity,
       tt.price,
       oi.quantity * tt.price AS total_price,
       o.order_date,
       o.status
FROM order_item oi
INNER JOIN orders o ON oi.order_id = o.id
INNER JOIN users u ON o.user_id = u.id
INNER JOIN ticket_type tt ON oi.ticket_type_id = tt.id
INNER JOIN event e ON tt.event_id = e.id
ORDER BY o.order_date DESC;

SELECT e.title AS event_title,
       tt.name AS ticket_type,
       tt.price,
       tt.quantity_total,
       COALESCE(SUM(oi.quantity), 0) AS quantity_sold,
       tt.quantity_total - COALESCE(SUM(oi.quantity), 0) AS quantity_available
FROM ticket_type tt
INNER JOIN event e ON tt.event_id = e.id
LEFT JOIN order_item oi ON tt.id = oi.ticket_type_id
GROUP BY e.title, tt.name, tt.price, tt.quantity_total
ORDER BY e.title, tt.name;

SELECT o.name AS organizer_name,
       o.email,
       e.title AS event_title
FROM event e
RIGHT JOIN organizer o ON e.organizer_id = o.id
ORDER BY o.name, e.title;

SELECT e.title AS event_title,
       tt.name AS ticket_category,
       COUNT(oi.id) AS orders_count,
       SUM(oi.quantity) AS total_tickets_sold,
       SUM(oi.quantity * tt.price) AS total_revenue
FROM event e
INNER JOIN ticket_type tt ON e.id = tt.event_id
LEFT JOIN order_item oi ON tt.id = oi.ticket_type_id
GROUP BY e.title, tt.name
ORDER BY e.title, total_revenue DESC;

SELECT u.name AS user_name,
       u.email,
       COUNT(DISTINCT o.id) AS total_orders,
       SUM(oi.quantity * tt.price) AS total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
LEFT JOIN order_item oi ON o.id = oi.order_id
LEFT JOIN ticket_type tt ON oi.ticket_type_id = tt.id
GROUP BY u.name, u.email
ORDER BY total_spent DESC NULLS LAST;

