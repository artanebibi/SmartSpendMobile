CREATE TABLE wallets
(
    id          BIGSERIAL PRIMARY KEY,
    created_by  TEXT        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name        TEXT        NOT NULL,
    invite_code TEXT        NOT NULL UNIQUE DEFAULT gen_random_uuid()::TEXT,
    created_at  TIMESTAMPTZ NOT NULL        DEFAULT NOW()
);

CREATE TABLE wallet_members
(
    id        BIGSERIAL PRIMARY KEY,
    wallet_id BIGINT      NOT NULL REFERENCES wallets (id) ON DELETE CASCADE,
    user_id   TEXT        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role      TEXT        NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (wallet_id, user_id)
);

CREATE TABLE wallet_transactions
(
    id             BIGSERIAL PRIMARY KEY,
    wallet_id      BIGINT      NOT NULL REFERENCES wallets (id) ON DELETE CASCADE,
    transaction_id INT         NOT NULL REFERENCES transactions (id) ON DELETE CASCADE,
    added_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (wallet_id, transaction_id)
);

CREATE TABLE wallet_transaction_splits
(
    id           BIGSERIAL PRIMARY KEY,
    wallet_tx_id BIGINT         NOT NULL REFERENCES wallet_transactions (id) ON DELETE CASCADE,
    user_id      TEXT           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    share        DECIMAL(12, 2) NOT NULL CHECK (share > 0),
    UNIQUE (wallet_tx_id, user_id)
);

CREATE TABLE wallet_settlements
(
    id           BIGSERIAL PRIMARY KEY,
    wallet_id    BIGINT         NOT NULL REFERENCES wallets (id) ON DELETE CASCADE,
    from_user_id TEXT           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    to_user_id   TEXT           NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    amount       DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    settled_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CHECK (from_user_id <> to_user_id)
);