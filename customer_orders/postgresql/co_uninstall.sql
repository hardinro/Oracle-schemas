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
--   This script drops the CO schema and all contained objects.
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
--   Connect as a superuser or the schema owner and run:
--     psql -f co_uninstall.sql
--
-- --------------------------------------------------------------------------

-- Fail fast on any error
\set ON_ERROR_STOP on

-- Use a default schema name of 'co' if not provided via -v co_schema=...
\if :{?co_schema}
  -- co_schema variable was provided via -v
\else
  \set co_schema co
\endif
\set co_schema_name :co_schema

\echo 'Dropping CO schema...'

DROP SCHEMA IF EXISTS :co_schema_name CASCADE;

\echo 'CO schema has been dropped (if it existed).'
