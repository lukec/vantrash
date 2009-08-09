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

-- TODO:
-- index area on name
-- index zone on area
-- index zone on name
-- index pickup on zone

COMMIT;
