-- =============================================================================
--  users — the one table this template owns
-- =============================================================================
--
--  Run this in the Neon SQL Editor (or any Postgres client) against your project
--  database. It is safe to run repeatedly: it creates the table only if it is
--  missing, then reports whether the schema is the one the application expects.
--
--  WHY THIS FILE EXISTS
--  --------------------
--  The application also creates this table by itself: `init_db()` in database.py
--  calls SQLAlchemy's create_all() at startup. This file is for the case where
--  you meet the database BEFORE the app — designing your schema in Neon first,
--  then building the website around it.
--
--  `users` is reserved by the template. Design your own tables alongside it
--  (customers, products, sale_points, transactions, ...) but do not redefine
--  `users`, or authentication will break in ways that are hard to diagnose.
--
--  KEEPING THIS IN SYNC
--  --------------------
--  models.py is the source of truth. The DDL below was generated from it, via:
--
--      python -c "from sqlalchemy.schema import CreateTable; \
--                 from sqlalchemy.dialects import postgresql; \
--                 from models import User; \
--                 print(CreateTable(User.__table__).compile(dialect=postgresql.dialect()))"
--
--  Re-run that after any change to the User model and update this file to match.
-- =============================================================================


-- -----------------------------------------------------------------------------
--  1. Create
-- -----------------------------------------------------------------------------
--  Deliberately no DEFAULT clauses. Every default (a UUID for id, 'local' for
--  auth_provider, TRUE for is_active, the current time for the timestamps) is
--  applied by the Python layer, not the database, so create_all() emits none
--  either. Adding server defaults here would still work, but the table would no
--  longer match what a fresh `create_all()` produces on someone else's machine.
--
--  The practical consequence: inserting a row BY HAND requires supplying those
--  values yourself. See section 3 for a ready-made example.

CREATE TABLE IF NOT EXISTS users (
    id              VARCHAR(36)              NOT NULL,
    email           VARCHAR(255)             NOT NULL,
    username        VARCHAR(100),
    hashed_password VARCHAR(255),
    auth_provider   VARCHAR(20)              NOT NULL,
    full_name       VARCHAR(200),
    avatar_url      VARCHAR(500),
    is_active       BOOLEAN                  NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id)
);

--  Unique indexes, not plain ones: two accounts sharing an email would let the
--  Google sign-in path attach to the wrong row. Names match SQLAlchemy's
--  convention (ix_<table>_<column>) so both creation paths agree.

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email    ON users (email);
CREATE UNIQUE INDEX IF NOT EXISTS ix_users_username ON users (username);


-- -----------------------------------------------------------------------------
--  2. Verify
-- -----------------------------------------------------------------------------
--  Compares the live table against what the application requires. Every row
--  should say OK. Problems sort to the top.
--
--  Column DEFAULTS are deliberately not checked — they differ harmlessly
--  depending on how the table was created. What is checked is the set of things
--  that actually break the app: column names, types, lengths and nullability.

WITH expected (column_name, data_type, max_length, is_nullable) AS (
    VALUES
        ('id',              'character varying',        36::int,   'NO'),
        ('email',           'character varying',        255::int,  'NO'),
        ('username',        'character varying',        100::int,  'YES'),
        ('hashed_password', 'character varying',        255::int,  'YES'),
        ('auth_provider',   'character varying',        20::int,   'NO'),
        ('full_name',       'character varying',        200::int,  'YES'),
        ('avatar_url',      'character varying',        500::int,  'YES'),
        ('is_active',       'boolean',                  NULL::int, 'NO'),
        ('created_at',      'timestamp with time zone', NULL::int, 'NO'),
        ('updated_at',      'timestamp with time zone', NULL::int, 'NO')
),
actual AS (
    SELECT
        column_name::text              AS column_name,
        data_type::text                AS data_type,
        character_maximum_length::int  AS max_length,
        is_nullable::text              AS is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'users'
),
diff AS (
    SELECT
        COALESCE(e.column_name, a.column_name) AS column_name,
        CASE
            WHEN a.column_name IS NULL
                THEN 'MISSING - the app will fail on this column'
            WHEN e.column_name IS NULL
                THEN 'EXTRA - not used by the app, harmless'
            WHEN e.data_type IS DISTINCT FROM a.data_type
                THEN 'WRONG TYPE - expected ' || e.data_type || ', found ' || a.data_type
            WHEN e.max_length IS DISTINCT FROM a.max_length
                THEN 'WRONG LENGTH - expected ' || COALESCE(e.max_length::text, 'none')
                     || ', found ' || COALESCE(a.max_length::text, 'none')
            WHEN e.is_nullable IS DISTINCT FROM a.is_nullable
                THEN 'WRONG NULLABILITY - expected is_nullable=' || e.is_nullable
                     || ', found ' || a.is_nullable
            ELSE 'OK'
        END AS status
    FROM expected e
    FULL OUTER JOIN actual a ON e.column_name = a.column_name
)
SELECT column_name, status
FROM diff
ORDER BY (status = 'OK'), column_name;


--  The unique indexes matter as much as the columns: without them the database
--  will happily store two accounts with the same email address.

SELECT
    want.indexname,
    CASE
        WHEN got.indexname IS NULL
            THEN 'MISSING - duplicate ' || want.column_name || ' values would be allowed'
        WHEN got.indexdef NOT LIKE 'CREATE UNIQUE INDEX%'
            THEN 'NOT UNIQUE - duplicate ' || want.column_name || ' values would be allowed'
        ELSE 'OK'
    END AS status
FROM (VALUES
        ('ix_users_email',    'email'),
        ('ix_users_username', 'username')
     ) AS want (indexname, column_name)
LEFT JOIN pg_indexes got
       ON got.indexname  = want.indexname
      AND got.schemaname = 'public'
ORDER BY (CASE WHEN got.indexname IS NULL THEN 0 ELSE 1 END), want.indexname;


-- -----------------------------------------------------------------------------
--  3. Optional — insert a row by hand
-- -----------------------------------------------------------------------------
--  Only useful for experimenting before the app exists. The app never needs this;
--  it fills these values from Python. Note that hashed_password is left NULL, so
--  this account cannot sign in with a password — which is exactly how a
--  Google-authenticated user looks in this table.
--
--  gen_random_uuid() is built into PostgreSQL 13+, so no extension is required.

-- INSERT INTO users (id, email, username, auth_provider, full_name, is_active,
--                    created_at, updated_at)
-- VALUES (gen_random_uuid()::text, 'student@example.com', 'student', 'local',
--         'Test Student', TRUE, now(), now());

-- SELECT id, email, username, auth_provider, is_active, created_at FROM users;
