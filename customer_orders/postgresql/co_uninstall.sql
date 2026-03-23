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
--   co_uninstall.sql - Removes the CO (Customer Orders) schema
--
-- DESCRIPTION
--   PostgreSQL 17 port of the Oracle CO schema removal script.
--   This script drops the CO schema and all its objects.
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
-- UNINSTALL INSTRUCTIONS
--   1. Connect to the target PostgreSQL database as a user with
--      DROP SCHEMA privileges.
--   2. Run this script with psql:
--        psql -d <database> -f co_uninstall.sql
--   3. Optionally set the CO_SCHEMA variable if a custom schema name was used:
--        psql -d <database> -v co_schema=my_schema -f co_uninstall.sql
--
-- --------------------------------------------------------------------------

-- Fail fast on any error
\set ON_ERROR_STOP on

-- Use the co_schema variable if provided, otherwise default to 'co'
\if :{?co_schema}
\else
  \set co_schema co
\endif
SELECT :'co_schema' AS schema_name \gset

-- Drop the schema and all contained objects
DROP SCHEMA IF EXISTS :schema_name CASCADE;

\echo ''
\echo 'CO schema has been dropped (if it existed).'
\echo ''
