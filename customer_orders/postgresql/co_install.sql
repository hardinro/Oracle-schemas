--
-- Copyright (c) 2023 Oracle
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
-- NAME
--   co_install.sql - Main installation script for CO schema creation
--
-- DESCRIPTION
--   PostgreSQL 17 port of the Oracle CO (Customer Orders) installation script.
--   CO is a sample schema resembling a generic customer orders management schema.
--
-- SCHEMA VERSION
--   21
--
-- ORIGINAL RELEASE DATE
--   08-FEB-2022
--
-- SUPPORTED with DB VERSIONS
--   PostgreSQL 17 and higher
--
-- INSTALL INSTRUCTIONS
--   1. Connect to a PostgreSQL database as a superuser or a role with
--      CREATE privileges (e.g., postgres)
--   2. Run this script:  psql -f co_install.sql
--   3. Optionally set the CO_SCHEMA variable to use a custom schema name:
--        psql -v co_schema=my_schema -f co_install.sql
--
-- UNINSTALL INSTRUCTIONS
--   Run the co_uninstall.sql script to remove the CO schema
--
-- --------------------------------------------------------------------------

-- Fail fast on any error
\set ON_ERROR_STOP on

-- Log installation to file
\o co_install.log

\echo ''
\echo 'Thank you for installing the PostgreSQL Customer Orders Sample Schema.'
\echo 'This installation script will stop on the first error encountered.'
\echo 'The entire installation will be logged into the co_install.log file.'
\echo ''

-- =======================================================
-- Set up the CO schema
-- =======================================================

-- Use a default schema name of 'co' if not provided via -v co_schema=...
SELECT COALESCE(:'co_schema', 'co') AS co_schema_name \gset

-- Drop the schema if it already exists (idempotent reinstall)
DROP SCHEMA IF EXISTS :co_schema_name CASCADE;

\echo 'Creating schema...'
CREATE SCHEMA :co_schema_name;

-- Set search_path so all objects are created in the CO schema
SET search_path TO :co_schema_name, public;

-- =======================================================
-- Create CO schema objects
-- =======================================================

\i co_create.sql

-- =======================================================
-- Populate tables with data
-- =======================================================

\i co_populate.sql

-- =======================================================
-- Installation validation
-- =======================================================

\echo ''
\echo 'Verification:'
\echo ''

SELECT 'customers'   AS "Table", 392  AS "expected", count(1) AS "actual" FROM customers
UNION ALL
SELECT 'stores',      23,  count(1) FROM stores
UNION ALL
SELECT 'products',    46,  count(1) FROM products
UNION ALL
SELECT 'orders',      1950, count(1) FROM orders
UNION ALL
SELECT 'shipments',   1892, count(1) FROM shipments
UNION ALL
SELECT 'order_items', 3914, count(1) FROM order_items
UNION ALL
SELECT 'inventory',   566,  count(1) FROM inventory;

\echo ''
\echo 'The installation of the sample schema is now finished.'
\echo 'Please check the installation verification output above.'
\echo ''
\echo 'Thank you for using PostgreSQL!'
\echo ''

-- Stop logging
\o
