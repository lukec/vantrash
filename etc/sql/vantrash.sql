BEGIN;

CREATE TABLE region (
    region_id INTEGER UNIQUE NOT NULL,
    name TEXT UNIQUE NOT NULL,
    "desc" TEXT NOT NULL,
    centre TEXT NOT NULL,
    kml_file TEXT NOT NULL
);

CREATE SEQUENCE region_seq;
CREATE INDEX region__name ON region (name);

CREATE TABLE district (
    district_id INTEGER UNIQUE NOT NULL,
    region_id INTEGER REFERENCES region (region_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    "desc" TEXT NOT NULL,
    centre TEXT NOT NULL,
    kml_file TEXT NOT NULL
);

CREATE SEQUENCE district_seq;
CREATE INDEX district__name ON district (name);
CREATE INDEX district__region_id ON district (region_id);

CREATE TABLE zone (
    zone_id INTEGER UNIQUE NOT NULL,
    name TEXT NOT NULL,
    district_id INTEGER REFERENCES district (district_id) ON DELETE CASCADE,
    area TEXT NOT NULL,
    "desc" TEXT NOT NULL,
    colour TEXT NOT NULL
);

CREATE SEQUENCE zone_seq;
CREATE INDEX zone__zone_id ON zone (zone_id);
CREATE INDEX zone__name ON zone (name);
CREATE INDEX zone__district_id ON zone (district_id);

CREATE TABLE pickup (
    pickup_id INTEGER UNIQUE NOT NULL,
    zone_id INTEGER REFERENCES zone (zone_id) ON DELETE CASCADE,
    day TEXT NOT NULL,
    flags TEXT NOT NULL
);

CREATE SEQUENCE pickup_seq;
CREATE INDEX pickup__zone_id ON pickup (zone_id);

CREATE TABLE reminder (
    reminder_id TEXT UNIQUE NOT NULL,
    zone_id INTEGER REFERENCES zone (zone_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    target TEXT NOT NULL,
    "offset" INTEGER NOT NULL,
    confirmed BOOLEAN NOT NULL,
    created_at timestamptz NOT NULL DEFAULT 'now'::timestamptz,
    next_pickup_id INTEGER REFERENCES pickup (pickup_id) ON DELETE CASCADE,
    last_notify_id INTEGER REFERENCES pickup (pickup_id) ON DELETE CASCADE,
    confirm_hash TEXT NOT NULL
);

CREATE INDEX reminder__reminder_id ON reminder (reminder_id);
CREATE INDEX reminder__zone_id ON reminder (zone_id);
CREATE INDEX reminder__confirm_hash ON reminder (confirm_hash);

COMMIT;
