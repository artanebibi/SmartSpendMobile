CREATE TABLE IF NOT EXISTS transaction_location
(
    id             BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT         NOT NULL,
    address        TEXT           NOT NULL,
    city           VARCHAR(255)   NOT NULL,
    lat            NUMERIC(10, 7) NOT NULL,
    lng            NUMERIC(10, 7) NOT NULL,
    CONSTRAINT fk_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_transaction_location_tx_id
    ON transaction_location (transaction_id);