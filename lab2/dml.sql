INSERT into organizer (name, email, phone)
VALUES
('MTS True Tech', 'it-meetup@mts.ru', '+79952525252'),
('Zvuchok', 'music@zvuchok.ru', '+79322322322');

INSERT INTO event (organizer_id, title, description, location, start_time, end_time)
SELECT id, 'Zvuchok Fest', 'Большой фестиваль музыки', 'Москва', '2025-06-01 18:00', '2025-06-01 23:00'
FROM organizer WHERE name='Zvuchok';

INSERT INTO event (organizer_id, title, description, location, start_time, end_time)
SELECT id, 'MTS Cloud Day', 'День Cloud-технологий', 'Москва', '2025-07-10 10:00', '2025-07-10 18:00'
FROM organizer WHERE name='MTS True Tech';

INSERT into users (name, email, password_hash)
VALUES
('Pavel', 'pavel@example.com', 'hash1'),
('Mikhail', 'mikhail@example.com', 'hash2');

INSERT into ticket_type (event_id, name, price, quantity_total)
SELECT id, 'Standard', 1500.00, 200 FROM event WHERE title='Zvuchok Fest';

INSERT into ticket_type (event_id, name, price, quantity_total)
SELECT id, 'VIP', 4500.00, 50 FROM event WHERE title='Zvuchok Fest';

INSERT into ticket_type (event_id, name, price, quantity_total)
SELECT id, 'Standard', 900.00, 100 FROM event WHERE title='MTS Cloud Day';

INSERT into ticket_type (event_id, name, price, quantity_total)
SELECT id, 'Premium', 2500.00, 30 FROM event WHERE title='MTS Cloud Day';

INSERT INTO orders (user_id, order_date, status)
SELECT id, '2025-05-15 14:30:00', 'completed'
FROM users WHERE name='Pavel';

INSERT INTO orders (user_id, order_date, status)
SELECT id, '2025-05-20 16:45:00', 'completed'
FROM users WHERE name='Mikhail';

INSERT INTO orders (user_id, order_date, status)
SELECT id, '2025-05-25 10:20:00', 'pending'
FROM users WHERE name='Pavel';

INSERT INTO order_item (order_id, ticket_type_id, quantity)
SELECT o.id, tt.id, 2
FROM orders o
JOIN ticket_type tt ON tt.name = 'Standard' AND tt.event_id = (SELECT id FROM event WHERE title='Zvuchok Fest')
WHERE o.user_id = (SELECT id FROM users WHERE name='Pavel')
  AND o.order_date = '2025-05-15 14:30:00';

INSERT INTO order_item (order_id, ticket_type_id, quantity)
SELECT o.id, tt.id, 1
FROM orders o
JOIN ticket_type tt ON tt.name = 'VIP' AND tt.event_id = (SELECT id FROM event WHERE title='Zvuchok Fest')
WHERE o.user_id = (SELECT id FROM users WHERE name='Mikhail')
  AND o.order_date = '2025-05-20 16:45:00';

INSERT INTO order_item (order_id, ticket_type_id, quantity)
SELECT o.id, tt.id, 3
FROM orders o
JOIN ticket_type tt ON tt.name = 'Standard' AND tt.event_id = (SELECT id FROM event WHERE title='MTS Cloud Day')
WHERE o.user_id = (SELECT id FROM users WHERE name='Pavel')
  AND o.order_date = '2025-05-25 10:20:00';

UPDATE ticket_type
SET quantity_sold = quantity_sold + 2
WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title='Zvuchok Fest');

UPDATE ticket_type
SET quantity_sold = quantity_sold + 1
WHERE name = 'VIP' AND event_id = (SELECT id FROM event WHERE title='Zvuchok Fest');

UPDATE ticket_type
SET quantity_sold = quantity_sold + 3
WHERE name = 'Standard' AND event_id = (SELECT id FROM event WHERE title='MTS Cloud Day');