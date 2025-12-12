CREATE TABLE organizer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT
);

CREATE TABLE event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES organizer(id),
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL
);

CREATE TABLE ticket_type (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES event(id),
    name TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity_total INT NOT NULL,
    quantity_sold INT DEFAULT 0
);

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    order_date TIMESTAMP DEFAULT now(),
    status TEXT NOT NULL
);

CREATE TABLE order_item (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    ticket_type_id UUID NOT NULL REFERENCES ticket_type(id),
    quantity INT NOT NULL
);
