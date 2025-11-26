SELECT e.title, SUM(tt.price * oi.quantity) AS total_sales
FROM order_item oi
JOIN ticket_type tt ON oi.ticket_type_id = tt.id
JOIN event e ON tt.event_id = e.id
GROUP BY e.title;

SELECT e.title, AVG(tt.price) AS avg_price
FROM ticket_type tt
JOIN event e ON tt.event_id = e.id
GROUP BY e.title;

SELECT tt.name, SUM(oi.quantity) AS sold
FROM order_item oi
JOIN ticket_type tt ON oi.ticket_type_id = tt.id
GROUP BY tt.name;

SELECT e.title, MIN(tt.price) AS min_price, MAX(tt.price) AS max_price
FROM ticket_type tt
JOIN event e ON tt.event_id = e.id
GROUP BY e.title;

SELECT o.name, COUNT(e.id) AS events_count
FROM organizer o
LEFT JOIN event e ON o.id = e.organizer_id
GROUP BY o.name;

SELECT e.title, AVG(tt.price) AS avg_price, SUM(tt.price * oi.quantity) AS total_revenue
FROM ticket_type tt
JOIN event e ON tt.event_id = e.id
LEFT JOIN order_item oi ON tt.id = oi.ticket_type_id
GROUP BY e.title
HAVING SUM(tt.price * COALESCE(oi.quantity, 0)) > 0
ORDER BY total_revenue DESC;

SELECT tt.name, 
       tt.quantity_sold,
       tt.quantity_total,
       ROUND(tt.quantity_sold * 100.0 / tt.quantity_total, 2) AS sold_percentage
FROM ticket_type tt
WHERE tt.quantity_total > 0
ORDER BY sold_percentage DESC;

SELECT status, COUNT(*) AS orders_count
FROM orders
GROUP BY status
ORDER BY orders_count DESC;