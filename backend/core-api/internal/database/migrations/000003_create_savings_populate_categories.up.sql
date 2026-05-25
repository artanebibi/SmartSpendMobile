CREATE TABLE savings
(
    id             BIGSERIAL PRIMARY KEY,
    name           VARCHAR(255) NOT NULL,
    owner_id       VARCHAR(255) NOT NULL,
    amount         REAL         NOT NULL,
    current_amount REAL         NOT NULL DEFAULT 0,
    "from"         TIMESTAMP    NOT NULL,
    "to"           TIMESTAMP    NOT NULL
);

INSERT INTO categories (name)
VALUES ('Groceries'),
       ('Health'),
       ('Home'),
       ('Restaurants & Dining'),
       ('Education'),
       ('Travel'),
       ('Entertainment'),
       ('Other'),
       ('Bills & Subscriptions'),
       ('Transportation'),
       ('Electronics')
ON CONFLICT DO NOTHING;