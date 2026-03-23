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
--   1. Connect to the target PostgreSQL database as a user with CREATE SCHEMA
--      privileges (e.g. the database owner or a superuser).
--   2. Run this script with psql:
--        psql -d <database> -f co_install.sql
--   3. Optionally set the CO_SCHEMA variable to use a custom schema name:
--        psql -d <database> -v co_schema=my_schema -f co_install.sql
--
-- UNINSTALL INSTRUCTIONS
--   Run the co_uninstall.sql script to remove the CO schema.
--
-- --------------------------------------------------------------------------

-- Fail fast on any error
\set ON_ERROR_STOP on

-- Log output to file
\o co_install.log

-- =======================================================
-- Installation description
-- =======================================================

\echo ''
\echo 'Thank you for installing the PostgreSQL Customer Orders Sample Schema.'
\echo 'This installation script will stop on the first error encountered.'
\echo 'The entire installation will be logged into the co_install.log log file.'
\echo ''

-- =======================================================
-- Schema setup
-- =======================================================

-- Use the co_schema variable if provided, otherwise default to 'co'
SELECT COALESCE(:'co_schema', 'co') AS schema_name \gset

-- Drop existing schema if present (idempotent reinstall)
DROP SCHEMA IF EXISTS :schema_name CASCADE;

-- Create the CO schema
CREATE SCHEMA :schema_name;

-- Set search path so all objects are created in the CO schema
SET search_path TO :schema_name, public;

\echo ''
\echo 'Created schema: ' :schema_name
\echo ''

-- =======================================================
-- Create CO schema objects
-- =======================================================

\echo 'Creating schema objects ...'
\i co_create.sql

-- =======================================================
-- Populate tables with data
-- =======================================================

\echo 'Populating tables ...'
\i co_populate.sql

-- =======================================================
-- Installation validation
-- =======================================================

\echo ''
\echo 'Verification:'
\echo ''

SELECT 'customers'   AS "Table", 392  AS "expected", COUNT(1) AS "actual" FROM customers
UNION ALL
SELECT 'stores'      AS "Table", 23   AS "expected", COUNT(1) AS "actual" FROM stores
UNION ALL
SELECT 'products'    AS "Table", 46   AS "expected", COUNT(1) AS "actual" FROM products
UNION ALL
SELECT 'orders'      AS "Table", 1950 AS "expected", COUNT(1) AS "actual" FROM orders
UNION ALL
SELECT 'shipments'   AS "Table", 1892 AS "expected", COUNT(1) AS "actual" FROM shipments
UNION ALL
SELECT 'order_items' AS "Table", 3914 AS "expected", COUNT(1) AS "actual" FROM order_items
UNION ALL
SELECT 'inventory'   AS "Table", 566  AS "expected", COUNT(1) AS "actual" FROM inventory;

-- =======================================================
-- Installation complete
-- =======================================================

\echo ''
\echo 'The installation of the sample schema is now finished.'
\echo 'Please check the installation verification output above.'
\echo ''
\echo 'Thank you for using PostgreSQL!'
\echo ''

-- Stop logging
\o
