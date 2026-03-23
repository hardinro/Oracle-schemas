--
-- NAME
--   co_validate.sql - Comprehensive validation suite for CO schema migration
--
-- DESCRIPTION
--   PostgreSQL 17 validation script for the Oracle-to-PostgreSQL migration
--   of the Customer Orders (CO) schema. Covers row counts, constraints,
--   identity/sequence correctness, view semantics, data integrity, negative
--   tests, and JSONB-specific validation.
--
-- USAGE
--   psql -v co_schema=co -f co_validate.sql
--
-- --------------------------------------------------------------------------

\set ON_ERROR_STOP on

-- Use a default schema name of 'co' if not provided
SELECT COALESCE(:'co_schema', 'co') AS co_schema_name \gset
SET search_path TO :co_schema_name, public;

\echo ''
\echo '============================================================'
\echo '  CO Schema Migration Validation Suite'
\echo '============================================================'
\echo ''

-- ============================================================
-- PHASE 1: Schema Validation - Objects created successfully
-- ============================================================

\echo '--- Phase 1: Schema Validation ---'
\echo ''

-- 1.1 Verify all 7 tables exist
\echo 'Test 1.1: Verify all tables exist'
DO $$
DECLARE
  expected_tables TEXT[] := ARRAY['customers','stores','products','orders','shipments','order_items','inventory'];
  tbl TEXT;
  missing TEXT := '';
BEGIN
  FOREACH tbl IN ARRAY expected_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = current_schema() AND table_name = tbl
    ) THEN
      missing := missing || tbl || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 7 tables exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing tables: %', rtrim(missing, ', ');
  END IF;
END $$;

-- 1.2 Verify all 4 views exist
\echo 'Test 1.2: Verify all views exist'
DO $$
DECLARE
  expected_views TEXT[] := ARRAY['customer_order_products','store_orders','product_reviews','product_orders'];
  vw TEXT;
  missing TEXT := '';
BEGIN
  FOREACH vw IN ARRAY expected_views LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.views
      WHERE table_schema = current_schema() AND table_name = vw
    ) THEN
      missing := missing || vw || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 4 views exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing views: %', rtrim(missing, ', ');
  END IF;
END $$;

-- 1.3 Verify data types are correctly mapped
\echo 'Test 1.3: Verify key data type mappings'
DO $$
DECLARE
  col_type TEXT;
BEGIN
  -- product_details should be jsonb
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = current_schema()
    AND table_name = 'products' AND column_name = 'product_details';
  IF col_type != 'jsonb' THEN
    RAISE EXCEPTION 'FAIL: products.product_details expected jsonb, got %', col_type;
  END IF;

  -- logo should be bytea
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = current_schema()
    AND table_name = 'stores' AND column_name = 'logo';
  IF col_type != 'bytea' THEN
    RAISE EXCEPTION 'FAIL: stores.logo expected bytea, got %', col_type;
  END IF;

  -- latitude should be numeric
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = current_schema()
    AND table_name = 'stores' AND column_name = 'latitude';
  IF col_type != 'numeric' THEN
    RAISE EXCEPTION 'FAIL: stores.latitude expected numeric, got %', col_type;
  END IF;

  -- order_tms should be timestamp without time zone
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_schema = current_schema()
    AND table_name = 'orders' AND column_name = 'order_tms';
  IF col_type != 'timestamp without time zone' THEN
    RAISE EXCEPTION 'FAIL: orders.order_tms expected timestamp, got %', col_type;
  END IF;

  RAISE NOTICE 'PASS: Key data type mappings are correct';
END $$;

-- ============================================================
-- PHASE 2: Data Validation - Row counts match
-- ============================================================

\echo ''
\echo '--- Phase 2: Data Validation ---'
\echo ''

\echo 'Test 2.1: Row count validation'
DO $$
DECLARE
  actual BIGINT;
  tbl TEXT;
  expected_count BIGINT;
  tables TEXT[] := ARRAY['customers','stores','products','orders','shipments','order_items','inventory'];
  counts BIGINT[] := ARRAY[392, 23, 46, 1950, 1892, 3914, 566];
  all_ok BOOLEAN := TRUE;
BEGIN
  FOR idx IN 1..array_length(tables, 1) LOOP
    tbl := tables[idx];
    expected_count := counts[idx];
    EXECUTE format('SELECT count(1) FROM %I', tbl) INTO actual;
    IF actual != expected_count THEN
      RAISE NOTICE 'FAIL: % expected % rows, got %', tbl, expected_count, actual;
      all_ok := FALSE;
    ELSE
      RAISE NOTICE 'PASS: % has % rows', tbl, actual;
    END IF;
  END LOOP;
  IF NOT all_ok THEN
    RAISE EXCEPTION 'FAIL: Row count mismatches detected';
  END IF;
END $$;

-- 2.2 Spot-check specific records
\echo 'Test 2.2: Spot-check key records'
DO $$
DECLARE
  v_name TEXT;
  v_email TEXT;
BEGIN
  -- Check first customer
  SELECT full_name, email_address INTO v_name, v_email
  FROM customers WHERE customer_id = 1;
  IF v_name != 'Tammy Bryant' OR v_email != 'tammy.bryant@internalmail' THEN
    RAISE EXCEPTION 'FAIL: Customer 1 mismatch: % / %', v_name, v_email;
  END IF;

  -- Check first store
  SELECT store_name INTO v_name FROM stores WHERE store_id = 1;
  IF v_name != 'Online' THEN
    RAISE EXCEPTION 'FAIL: Store 1 expected Online, got %', v_name;
  END IF;

  RAISE NOTICE 'PASS: Key record spot-checks passed';
END $$;

-- ============================================================
-- PHASE 3: Constraint Validation - PK, FK, UNIQUE, CHECK enforced
-- ============================================================

\echo ''
\echo '--- Phase 3: Constraint Validation ---'
\echo ''

\echo 'Test 3.1: Verify primary key constraints exist'
DO $$
DECLARE
  expected_pks TEXT[] := ARRAY[
    'customers_pk', 'stores_pk', 'products_pk', 'orders_pk',
    'shipments_pk', 'order_items_pk', 'inventory_pk'
  ];
  pk TEXT;
  missing TEXT := '';
BEGIN
  FOREACH pk IN ARRAY expected_pks LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_schema = current_schema()
        AND constraint_name = pk
        AND constraint_type = 'PRIMARY KEY'
    ) THEN
      missing := missing || pk || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 7 primary key constraints exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing PKs: %', rtrim(missing, ', ');
  END IF;
END $$;

\echo 'Test 3.2: Verify foreign key constraints exist'
DO $$
DECLARE
  expected_fks TEXT[] := ARRAY[
    'orders_customer_id_fk', 'orders_store_id_fk',
    'shipments_store_id_fk', 'shipments_customer_id_fk',
    'order_items_order_id_fk', 'order_items_shipment_id_fk',
    'order_items_product_id_fk',
    'inventory_store_id_fk', 'inventory_product_id_fk'
  ];
  fk TEXT;
  missing TEXT := '';
BEGIN
  FOREACH fk IN ARRAY expected_fks LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_schema = current_schema()
        AND constraint_name = fk
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
      missing := missing || fk || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 9 foreign key constraints exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing FKs: %', rtrim(missing, ', ');
  END IF;
END $$;

\echo 'Test 3.3: Verify UNIQUE constraints exist'
DO $$
DECLARE
  expected_uniques TEXT[] := ARRAY[
    'customers_email_u', 'store_name_u',
    'order_items_product_u', 'inventory_store_product_u'
  ];
  uc TEXT;
  missing TEXT := '';
BEGIN
  FOREACH uc IN ARRAY expected_uniques LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_schema = current_schema()
        AND constraint_name = uc
        AND constraint_type = 'UNIQUE'
    ) THEN
      missing := missing || uc || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 4 UNIQUE constraints exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing UNIQUEs: %', rtrim(missing, ', ');
  END IF;
END $$;

\echo 'Test 3.4: Verify CHECK constraints exist'
DO $$
DECLARE
  expected_checks TEXT[] := ARRAY[
    'store_at_least_one_address_c', 'orders_status_c', 'shipment_status_c'
  ];
  cc TEXT;
  missing TEXT := '';
BEGIN
  FOREACH cc IN ARRAY expected_checks LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_schema = current_schema()
        AND constraint_name = cc
        AND constraint_type = 'CHECK'
    ) THEN
      missing := missing || cc || ', ';
    END IF;
  END LOOP;
  IF missing = '' THEN
    RAISE NOTICE 'PASS: All 3 CHECK constraints exist';
  ELSE
    RAISE EXCEPTION 'FAIL: Missing CHECKs: %', rtrim(missing, ', ');
  END IF;
END $$;

-- ============================================================
-- PHASE 4: Functional Validation - Views return correct results
-- ============================================================

\echo ''
\echo '--- Phase 4: Functional Validation ---'
\echo ''

\echo 'Test 4.1: customer_order_products view returns data'
DO $$
DECLARE
  cnt BIGINT;
BEGIN
  SELECT count(*) INTO cnt FROM customer_order_products;
  IF cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: customer_order_products view returned 0 rows';
  ELSE
    RAISE NOTICE 'PASS: customer_order_products view returned % rows', cnt;
  END IF;
END $$;

\echo 'Test 4.2: store_orders view returns data with grouping totals'
DO $$
DECLARE
  grand_total_cnt BIGINT;
  store_total_cnt BIGINT;
BEGIN
  SELECT count(*) INTO grand_total_cnt
  FROM store_orders WHERE total = 'GRAND TOTAL';
  SELECT count(*) INTO store_total_cnt
  FROM store_orders WHERE total = 'STORE TOTAL';
  IF grand_total_cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: store_orders has no GRAND TOTAL rows';
  END IF;
  IF store_total_cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: store_orders has no STORE TOTAL rows';
  END IF;
  RAISE NOTICE 'PASS: store_orders view has % GRAND TOTAL and % STORE TOTAL rows', grand_total_cnt, store_total_cnt;
END $$;

\echo 'Test 4.3: product_reviews view returns JSON-derived data'
DO $$
DECLARE
  cnt BIGINT;
  has_ratings BOOLEAN;
BEGIN
  SELECT count(*), bool_or(rating IS NOT NULL) INTO cnt, has_ratings
  FROM product_reviews;
  IF cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: product_reviews view returned 0 rows';
  END IF;
  IF NOT has_ratings THEN
    RAISE EXCEPTION 'FAIL: product_reviews has no non-null ratings';
  END IF;
  RAISE NOTICE 'PASS: product_reviews view returned % rows with ratings', cnt;
END $$;

\echo 'Test 4.4: product_orders view returns aggregated data'
DO $$
DECLARE
  cnt BIGINT;
BEGIN
  SELECT count(*) INTO cnt FROM product_orders;
  IF cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: product_orders view returned 0 rows';
  ELSE
    RAISE NOTICE 'PASS: product_orders view returned % rows', cnt;
  END IF;
END $$;

-- ============================================================
-- PHASE 5: Identity Validation - Auto-increment behaves correctly
-- ============================================================

\echo ''
\echo '--- Phase 5: Identity Validation ---'
\echo ''

\echo 'Test 5.1: Identity sequences are set correctly after data load'
DO $$
DECLARE
  seq_val BIGINT;
  max_val BIGINT;
  tbl TEXT;
  col TEXT;
  tables TEXT[] := ARRAY['customers','stores','products','orders','shipments','inventory'];
  cols TEXT[] := ARRAY['customer_id','store_id','product_id','order_id','shipment_id','inventory_id'];
BEGIN
  FOR idx IN 1..array_length(tables, 1) LOOP
    tbl := tables[idx];
    col := cols[idx];
    EXECUTE format('SELECT last_value FROM pg_get_serial_sequence(%L, %L)', tbl, col)
      INTO seq_val;
    -- Actually query the sequence
    EXECUTE format('SELECT last_value FROM %s', pg_get_serial_sequence(tbl, col))
      INTO seq_val;
    EXECUTE format('SELECT MAX(%I) FROM %I', col, tbl) INTO max_val;
    IF seq_val < max_val THEN
      RAISE EXCEPTION 'FAIL: % sequence value (%) < max % (%)', tbl, seq_val, col, max_val;
    ELSE
      RAISE NOTICE 'PASS: %.% sequence=%, max=%', tbl, col, seq_val, max_val;
    END IF;
  END LOOP;
END $$;

\echo 'Test 5.2: New inserts get auto-generated IDs'
DO $$
DECLARE
  new_id INTEGER;
BEGIN
  INSERT INTO customers (email_address, full_name)
  VALUES ('test.identity@validation.test', 'Identity Test')
  RETURNING customer_id INTO new_id;

  IF new_id IS NULL OR new_id <= 392 THEN
    RAISE EXCEPTION 'FAIL: Auto-generated customer_id (%) should be > 392', new_id;
  ELSE
    RAISE NOTICE 'PASS: Auto-generated customer_id = %', new_id;
  END IF;

  -- Clean up test row
  DELETE FROM customers WHERE email_address = 'test.identity@validation.test';
END $$;

-- ============================================================
-- PHASE 6: Behavioral Equivalence - Negative tests
-- ============================================================

\echo ''
\echo '--- Phase 6: Behavioral Equivalence (Negative Tests) ---'
\echo ''

\echo 'Test 6.1: CHECK constraint - invalid order_status rejected'
DO $$
BEGIN
  INSERT INTO orders (order_tms, customer_id, order_status, store_id)
  VALUES (CURRENT_TIMESTAMP, 1, 'INVALID', 1);
  RAISE EXCEPTION 'FAIL: Invalid order_status was accepted';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: Invalid order_status correctly rejected';
END $$;

\echo 'Test 6.2: CHECK constraint - invalid shipment_status rejected'
DO $$
BEGIN
  INSERT INTO shipments (store_id, customer_id, delivery_address, shipment_status)
  VALUES (1, 1, '123 Test St', 'BOGUS');
  RAISE EXCEPTION 'FAIL: Invalid shipment_status was accepted';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: Invalid shipment_status correctly rejected';
END $$;

\echo 'Test 6.3: CHECK constraint - store must have at least one address'
DO $$
BEGIN
  INSERT INTO stores (store_name, web_address, physical_address)
  VALUES ('No Address Store', NULL, NULL);
  RAISE EXCEPTION 'FAIL: Store with no address was accepted';
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'PASS: Store with no address correctly rejected';
END $$;

\echo 'Test 6.4: UNIQUE constraint - duplicate email rejected'
DO $$
BEGIN
  INSERT INTO customers (email_address, full_name)
  VALUES ('tammy.bryant@internalmail', 'Duplicate Test');
  RAISE EXCEPTION 'FAIL: Duplicate email was accepted';
EXCEPTION WHEN unique_violation THEN
  RAISE NOTICE 'PASS: Duplicate email correctly rejected';
END $$;

\echo 'Test 6.5: FK constraint - order with non-existent customer rejected'
DO $$
BEGIN
  INSERT INTO orders (order_tms, customer_id, order_status, store_id)
  VALUES (CURRENT_TIMESTAMP, 999999, 'OPEN', 1);
  RAISE EXCEPTION 'FAIL: Order with non-existent customer was accepted';
EXCEPTION WHEN foreign_key_violation THEN
  RAISE NOTICE 'PASS: FK violation correctly rejected';
END $$;

\echo 'Test 6.6: JSONB type validation - invalid JSON rejected'
DO $$
BEGIN
  INSERT INTO products (product_name, unit_price, product_details)
  VALUES ('Bad JSON Product', 9.99, 'not valid json'::jsonb);
  RAISE EXCEPTION 'FAIL: Invalid JSON was accepted into JSONB column';
EXCEPTION WHEN invalid_text_representation THEN
  RAISE NOTICE 'PASS: Invalid JSON correctly rejected by JSONB type';
END $$;

\echo 'Test 6.7: JSONB query - can query product details'
DO $$
DECLARE
  cnt BIGINT;
BEGIN
  SELECT count(*) INTO cnt
  FROM products
  WHERE product_details->>'colour' = 'white';
  IF cnt = 0 THEN
    RAISE EXCEPTION 'FAIL: No products found with colour=white in JSONB';
  ELSE
    RAISE NOTICE 'PASS: Found % products with colour=white via JSONB query', cnt;
  END IF;
END $$;

-- ============================================================
-- Summary
-- ============================================================

\echo ''
\echo '============================================================'
\echo '  All validation tests completed successfully!'
\echo '============================================================'
\echo ''
