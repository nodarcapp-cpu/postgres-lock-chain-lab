CREATE TABLE orders (
    id integer PRIMARY KEY,
    status text NOT NULL
);

INSERT INTO orders (id, status)
VALUES (1, 'pending');
