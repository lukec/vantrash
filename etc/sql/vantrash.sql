BEGIN;

CREATE TABLE area (
    name TEXT PRIMARY KEY,
    desc TEXT NOT NULL,
    centre TEXT NOT NULL
);

CREATE TABLE zone (
    name TEXT PRIMARY KEY,
    area TEXT NOT NULL,
    desc TEXT NOT NULL,
    colour TEXT NOT NULL
);

CREATE TABLE pickup (
    id INTEGER PRIMARY KEY,
    zone TEXT NOT NULL,
    day TEXT NOT NULL,
    flags TEXT NOT NULL
);

CREATE TABLE reminder (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    target TEXT NOT NULL,
    zone TEXT NOT NULL,
    offset INTEGER NOT NULL,
    confirmed BOOLEAN NOT NULL,
    created_at INTEGER NOT NULL,
    next_pickup INTEGER NOT NULL,
    last_notified INTEGER NOT NULL,
    confirm_hash TEXT NOT NULL,
    payment_period TEXT,
    expiry INTEGER NOT NULL DEFAULT 0,
    coupon TEXT,
    subscription_profile_id TEXT
);

-- TODO:
-- index area on name
-- index zone on area
-- index zone on name
-- index pickup on zone
-- index reminder on id
-- index reminder on zone
-- index reminder on confirm_hash

COMMIT;
