INSERT INTO users(name, email, password_hash) VALUES('Peter', 'peter@example.com', 'hash3');

INSERT INTO orders (user_id, order_date, status)
SELECT id, '2025-06-05 12:00:00', 'completed'
FROM users WHERE name='Peter';

UPDATE ticket_type
SET quantity_sold = quantity_sold + 2
WHERE name='VIP' AND event_id = (SELECT id FROM event WHERE title='Zvuchok Fest');

UPDATE orders
SET status = 'completed'
WHERE status = 'pending' AND order_date < '2025-05-30';

DELETE FROM orders WHERE order_date < '2025-06-01';

DELETE FROM users 
WHERE id NOT IN (SELECT DISTINCT user_id FROM orders WHERE user_id IS NOT NULL)
  AND name = 'Peter';
