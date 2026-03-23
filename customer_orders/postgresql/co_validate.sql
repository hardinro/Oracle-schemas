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
--   co_validate.sql - Comprehensive validation suite for CO schema
--
-- DESCRIPTION
--   PostgreSQL 17 validation script for the Customer Orders schema migration.
--   Tests schema structure, data integrity, constraints, views, identities,
--   and behavioral equivalence.
--
-- USAGE
--   psql -d <database> -f co_validate.sql
--   Ensure search_path includes the CO schema before running.
--
-- --------------------------------------------------------------------------

\set ON_ERROR_STOP on

\echo ''
\echo '================================================================'
\echo '  CO Schema Migration Validation Suite'
\echo '  Oracle 19c -> PostgreSQL 17'
\echo '================================================================'
\echo ''

-- =======================================================
-- PHASE 1: Schema Validation — Objects created successfully
-- =======================================================

\echo '--- Phase 1: Schema Validation ---'
\echo ''

-- 1.1 Verify all 7 tables exist
\echo 'Test 1.1: All tables exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.tables
  WHERE table_schema = current_schema()
    AND table_type = 'BASE TABLE'
    AND table_name IN ('customers','stores','products','orders','shipments','order_items','inventory');
  IF v_count = 7 THEN
    RAISE NOTICE 'PASS — 7/7 tables found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 7 tables, found %', v_count;
  END IF;
END $$;

-- 1.2 Verify all 4 views exist
\echo 'Test 1.2: All views exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.views
  WHERE table_schema = current_schema()
    AND table_name IN ('customer_order_products','store_orders','product_reviews','product_orders');
  IF v_count = 4 THEN
    RAISE NOTICE 'PASS — 4/4 views found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 4 views, found %', v_count;
  END IF;
END $$;

-- 1.3 Verify data types are correctly mapped
\echo 'Test 1.3: Key data type mappings'
DO $$
DECLARE
  v_type TEXT;
BEGIN
  -- customers.email_address should be varchar
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = current_schema() AND table_name = 'customers' AND column_name = 'email_address';
  IF v_type <> 'character varying' THEN
    RAISE EXCEPTION 'FAIL — customers.email_address type is %, expected character varying', v_type;
  END IF;

  -- stores.latitude should be numeric
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = current_schema() AND table_name = 'stores' AND column_name = 'latitude';
  IF v_type <> 'numeric' THEN
    RAISE EXCEPTION 'FAIL — stores.latitude type is %, expected numeric', v_type;
  END IF;

  -- stores.logo should be bytea
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = current_schema() AND table_name = 'stores' AND column_name = 'logo';
  IF v_type <> 'bytea' THEN
    RAISE EXCEPTION 'FAIL — stores.logo type is %, expected bytea', v_type;
  END IF;

  -- products.product_details should be jsonb
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = current_schema() AND table_name = 'products' AND column_name = 'product_details';
  IF v_type <> 'jsonb' THEN
    RAISE EXCEPTION 'FAIL — products.product_details type is %, expected jsonb', v_type;
  END IF;

  -- orders.order_tms should be timestamp
  SELECT data_type INTO v_type
  FROM information_schema.columns
  WHERE table_schema = current_schema() AND table_name = 'orders' AND column_name = 'order_tms';
  IF v_type NOT LIKE 'timestamp%' THEN
    RAISE EXCEPTION 'FAIL — orders.order_tms type is %, expected timestamp', v_type;
  END IF;

  RAISE NOTICE 'PASS — All key data types correctly mapped';
END $$;

-- 1.4 Verify indexes exist
\echo 'Test 1.4: Indexes exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM pg_indexes
  WHERE schemaname = current_schema()
    AND indexname IN (
      'customers_name_i', 'orders_customer_id_i', 'orders_store_id_i',
      'shipments_store_id_i', 'shipments_customer_id_i',
      'order_items_shipment_id_i', 'inventory_product_id_i'
    );
  IF v_count = 7 THEN
    RAISE NOTICE 'PASS — 7/7 custom indexes found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 7 indexes, found %', v_count;
  END IF;
END $$;

-- =======================================================
-- PHASE 2: Data Validation — Row counts match
-- =======================================================

\echo ''
\echo '--- Phase 2: Data Validation ---'
\echo ''

-- 2.1 Row count validation
\echo 'Test 2.1: Row counts match expected values'
DO $$
DECLARE
  v_count INTEGER;
  v_table TEXT;
  v_expected INTEGER;
  v_rec RECORD;
BEGIN
  FOR v_rec IN
    SELECT * FROM (VALUES
      ('customers', 392), ('stores', 23), ('products', 46),
      ('orders', 1950), ('shipments', 1892), ('order_items', 3914),
      ('inventory', 566)
    ) AS t(tbl, expected)
  LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I', v_rec.tbl) INTO v_count;
    IF v_count <> v_rec.expected THEN
      RAISE EXCEPTION 'FAIL — % has % rows, expected %', v_rec.tbl, v_count, v_rec.expected;
    END IF;
  END LOOP;
  RAISE NOTICE 'PASS — All 7 tables have correct row counts';
END $$;

-- 2.2 Spot-check key customer records
\echo 'Test 2.2: Spot-check customer records'
DO $$
DECLARE
  v_name TEXT;
BEGIN
  SELECT full_name INTO v_name FROM customers WHERE customer_id = 1;
  IF v_name <> 'Tammy Bryant' THEN
    RAISE EXCEPTION 'FAIL — Customer 1 name is %, expected Tammy Bryant', v_name;
  END IF;
  SELECT full_name INTO v_name FROM customers WHERE customer_id = 392;
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'FAIL — Customer 392 not found';
  END IF;
  RAISE NOTICE 'PASS — Key customer records verified';
END $$;

-- 2.3 Spot-check order timestamps
\echo 'Test 2.3: Spot-check order timestamps'
DO $$
DECLARE
  v_tms TIMESTAMP;
BEGIN
  SELECT order_tms INTO v_tms FROM orders WHERE order_id = 1;
  IF v_tms IS NULL THEN
    RAISE EXCEPTION 'FAIL — Order 1 timestamp is NULL';
  END IF;
  -- Verify the date portion is correct (2021-02-04)
  IF v_tms::date <> '2021-02-04'::date THEN
    RAISE EXCEPTION 'FAIL — Order 1 date is %, expected 2021-02-04', v_tms::date;
  END IF;
  RAISE NOTICE 'PASS — Order timestamps verified (order 1: %)', v_tms;
END $$;

-- 2.4 Verify JSONB product data
\echo 'Test 2.4: JSONB product data integrity'
DO $$
DECLARE
  v_count INTEGER;
  v_colour TEXT;
BEGIN
  -- All products with details should have valid JSONB
  SELECT COUNT(*) INTO v_count FROM products WHERE product_details IS NOT NULL;
  IF v_count <> 46 THEN
    RAISE EXCEPTION 'FAIL — Expected 46 products with details, found %', v_count;
  END IF;

  -- Spot-check a specific product's JSON
  SELECT product_details ->> 'colour' INTO v_colour
  FROM products WHERE product_id = 1;
  IF v_colour IS NULL THEN
    RAISE EXCEPTION 'FAIL — Product 1 has no colour in JSONB';
  END IF;

  RAISE NOTICE 'PASS — JSONB data verified (% products with details, product 1 colour: %)', v_count, v_colour;
END $$;

-- =======================================================
-- PHASE 3: Constraint Validation — PK, FK, UNIQUE, CHECK
-- =======================================================

\echo ''
\echo '--- Phase 3: Constraint Validation ---'
\echo ''

-- 3.1 Primary key constraints
\echo 'Test 3.1: Primary key constraints exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.table_constraints
  WHERE constraint_schema = current_schema()
    AND constraint_type = 'PRIMARY KEY'
    AND constraint_name IN (
      'customers_pk','stores_pk','products_pk','orders_pk',
      'shipments_pk','order_items_pk','inventory_pk'
    );
  IF v_count = 7 THEN
    RAISE NOTICE 'PASS — 7/7 primary key constraints found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 7 PK constraints, found %', v_count;
  END IF;
END $$;

-- 3.2 Foreign key constraints
\echo 'Test 3.2: Foreign key constraints exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.table_constraints
  WHERE constraint_schema = current_schema()
    AND constraint_type = 'FOREIGN KEY'
    AND constraint_name IN (
      'orders_customer_id_fk','orders_store_id_fk',
      'shipments_store_id_fk','shipments_customer_id_fk',
      'order_items_order_id_fk','order_items_shipment_id_fk',
      'order_items_product_id_fk',
      'inventory_store_id_fk','inventory_product_id_fk'
    );
  IF v_count = 9 THEN
    RAISE NOTICE 'PASS — 9/9 foreign key constraints found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 9 FK constraints, found %', v_count;
  END IF;
END $$;

-- 3.3 Unique constraints
\echo 'Test 3.3: Unique constraints exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.table_constraints
  WHERE constraint_schema = current_schema()
    AND constraint_type = 'UNIQUE'
    AND constraint_name IN (
      'customers_email_u','store_name_u',
      'order_items_product_u','inventory_store_product_u'
    );
  IF v_count = 4 THEN
    RAISE NOTICE 'PASS — 4/4 unique constraints found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 4 UNIQUE constraints, found %', v_count;
  END IF;
END $$;

-- 3.4 Check constraints
\echo 'Test 3.4: Check constraints exist'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM information_schema.table_constraints
  WHERE constraint_schema = current_schema()
    AND constraint_type = 'CHECK'
    AND constraint_name IN (
      'store_at_least_one_address_c',
      'orders_status_c',
      'shipment_status_c'
    );
  IF v_count = 3 THEN
    RAISE NOTICE 'PASS — 3/3 check constraints found';
  ELSE
    RAISE EXCEPTION 'FAIL — Expected 3 CHECK constraints, found %', v_count;
  END IF;
END $$;

-- 3.5 Negative test: PK violation
\echo 'Test 3.5: Negative test — PK violation rejected'
DO $$
BEGIN
  INSERT INTO customers (customer_id, email_address, full_name)
    VALUES (1, 'duplicate@test.com', 'Duplicate');
  RAISE EXCEPTION 'FAIL — PK violation was not rejected';
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'PASS — PK duplicate correctly rejected';
END $$;

-- 3.6 Negative test: FK violation
\echo 'Test 3.6: Negative test — FK violation rejected'
DO $$
BEGIN
  INSERT INTO orders (order_id, order_tms, customer_id, order_status, store_id)
    VALUES (99999, CURRENT_TIMESTAMP, 99999, 'OPEN', 1);
  RAISE EXCEPTION 'FAIL — FK violation was not rejected';
EXCEPTION
  WHEN foreign_key_violation THEN
    RAISE NOTICE 'PASS — FK violation correctly rejected';
END $$;

-- 3.7 Negative test: CHECK constraint violation (order_status)
\echo 'Test 3.7: Negative test — CHECK constraint violation rejected'
DO $$
BEGIN
  INSERT INTO orders (order_id, order_tms, customer_id, order_status, store_id)
    VALUES (99998, CURRENT_TIMESTAMP, 1, 'INVALID', 1);
  RAISE EXCEPTION 'FAIL — CHECK violation was not rejected';
EXCEPTION
  WHEN check_violation THEN
    RAISE NOTICE 'PASS — CHECK violation correctly rejected';
END $$;

-- 3.8 Negative test: UNIQUE constraint violation (email)
\echo 'Test 3.8: Negative test — UNIQUE violation rejected'
DO $$
BEGIN
  INSERT INTO customers (customer_id, email_address, full_name)
    VALUES (99999, 'tammy.bryant@internalmail', 'Duplicate Email');
  RAISE EXCEPTION 'FAIL — UNIQUE violation was not rejected';
EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'PASS — UNIQUE email violation correctly rejected';
END $$;

-- 3.9 Negative test: NOT NULL violation
\echo 'Test 3.9: Negative test — NOT NULL violation rejected'
DO $$
BEGIN
  INSERT INTO customers (customer_id, email_address, full_name)
    VALUES (99997, NULL, 'Missing Email');
  RAISE EXCEPTION 'FAIL — NOT NULL violation was not rejected';
EXCEPTION
  WHEN not_null_violation THEN
    RAISE NOTICE 'PASS — NOT NULL violation correctly rejected';
END $$;

-- 3.10 Negative test: Store address CHECK constraint
\echo 'Test 3.10: Negative test — Store address CHECK constraint'
DO $$
BEGIN
  INSERT INTO stores (store_id, store_name, web_address, physical_address)
    VALUES (99999, 'Test No Address', NULL, NULL);
  RAISE EXCEPTION 'FAIL — Store address CHECK was not enforced';
EXCEPTION
  WHEN check_violation THEN
    RAISE NOTICE 'PASS — Store must have at least one address';
END $$;

-- 3.11 Negative test: Shipment status CHECK constraint
\echo 'Test 3.11: Negative test — Shipment status CHECK constraint'
DO $$
BEGIN
  INSERT INTO shipments (shipment_id, store_id, customer_id, delivery_address, shipment_status)
    VALUES (99999, 1, 1, '123 Test St', 'INVALID');
  RAISE EXCEPTION 'FAIL — Shipment status CHECK was not enforced';
EXCEPTION
  WHEN check_violation THEN
    RAISE NOTICE 'PASS — Shipment status CHECK correctly enforced';
END $$;

-- 3.12 Negative test: Invalid JSONB rejected
\echo 'Test 3.12: Negative test — Invalid JSONB rejected'
DO $$
BEGIN
  INSERT INTO products (product_id, product_name, unit_price, product_details)
    VALUES (99999, 'Bad JSON', 1.00, 'not valid json'::jsonb);
  RAISE EXCEPTION 'FAIL — Invalid JSONB was not rejected';
EXCEPTION
  WHEN invalid_text_representation THEN
    RAISE NOTICE 'PASS — Invalid JSONB correctly rejected';
END $$;

-- =======================================================
-- PHASE 4: Functional Validation — Views return correct results
-- =======================================================

\echo ''
\echo '--- Phase 4: Functional Validation ---'
\echo ''

-- 4.1 customer_order_products view
\echo 'Test 4.1: customer_order_products view returns data'
DO $$
DECLARE
  v_count INTEGER;
  v_items TEXT;
BEGIN
  SELECT COUNT(*) INTO v_count FROM customer_order_products;
  IF v_count <> 1950 THEN
    RAISE EXCEPTION 'FAIL — customer_order_products has % rows, expected 1950', v_count;
  END IF;

  -- Verify STRING_AGG produces a comma-separated list
  SELECT items INTO v_items FROM customer_order_products WHERE order_id = 1;
  IF v_items IS NULL OR v_items = '' THEN
    RAISE EXCEPTION 'FAIL — customer_order_products items is empty for order 1';
  END IF;

  RAISE NOTICE 'PASS — customer_order_products: % rows, order 1 items: %', v_count, LEFT(v_items, 60);
END $$;

-- 4.2 store_orders view
\echo 'Test 4.2: store_orders view returns data with grouping sets'
DO $$
DECLARE
  v_total_count INTEGER;
  v_grand_total_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_total_count FROM store_orders;
  IF v_total_count = 0 THEN
    RAISE EXCEPTION 'FAIL — store_orders view is empty';
  END IF;

  SELECT COUNT(*) INTO v_grand_total_count FROM store_orders WHERE total = 'GRAND TOTAL';
  IF v_grand_total_count <> 1 THEN
    RAISE EXCEPTION 'FAIL — Expected 1 GRAND TOTAL row, found %', v_grand_total_count;
  END IF;

  RAISE NOTICE 'PASS — store_orders: % total rows, % GRAND TOTAL row(s)', v_total_count, v_grand_total_count;
END $$;

-- 4.3 product_reviews view (JSONB lateral join)
\echo 'Test 4.3: product_reviews view returns data from JSONB'
DO $$
DECLARE
  v_count INTEGER;
  v_avg NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_count FROM product_reviews;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAIL — product_reviews view is empty';
  END IF;

  -- Verify avg_rating is computed
  SELECT avg_rating INTO v_avg FROM product_reviews LIMIT 1;
  IF v_avg IS NULL THEN
    RAISE EXCEPTION 'FAIL — product_reviews avg_rating is NULL';
  END IF;

  RAISE NOTICE 'PASS — product_reviews: % rows, avg_rating computed', v_count;
END $$;

-- 4.4 product_orders view
\echo 'Test 4.4: product_orders view returns data'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM product_orders;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAIL — product_orders view is empty';
  END IF;
  RAISE NOTICE 'PASS — product_orders: % rows', v_count;
END $$;

-- =======================================================
-- PHASE 5: Identity Validation — Auto-increment works post-load
-- =======================================================

\echo ''
\echo '--- Phase 5: Identity Validation ---'
\echo ''

-- 5.1 Test identity columns generate correct next values
\echo 'Test 5.1: Identity auto-increment works after data load'
DO $$
DECLARE
  v_new_id INTEGER;
  v_max_id INTEGER;
BEGIN
  -- Test customers identity
  SELECT MAX(customer_id) INTO v_max_id FROM customers;
  INSERT INTO customers (email_address, full_name)
    VALUES ('identity.test@example.com', 'Identity Test')
    RETURNING customer_id INTO v_new_id;
  IF v_new_id <= v_max_id THEN
    RAISE EXCEPTION 'FAIL — New customer_id % is not greater than max %', v_new_id, v_max_id;
  END IF;
  -- Clean up
  DELETE FROM customers WHERE customer_id = v_new_id;
  RAISE NOTICE 'PASS — customers identity: max was %, new id is %', v_max_id, v_new_id;
END $$;

DO $$
DECLARE
  v_new_id INTEGER;
  v_max_id INTEGER;
BEGIN
  -- Test stores identity
  SELECT MAX(store_id) INTO v_max_id FROM stores;
  INSERT INTO stores (store_name, web_address)
    VALUES ('Identity Test Store', 'https://test.example.com')
    RETURNING store_id INTO v_new_id;
  IF v_new_id <= v_max_id THEN
    RAISE EXCEPTION 'FAIL — New store_id % is not greater than max %', v_new_id, v_max_id;
  END IF;
  DELETE FROM stores WHERE store_id = v_new_id;
  RAISE NOTICE 'PASS — stores identity: max was %, new id is %', v_max_id, v_new_id;
END $$;

DO $$
DECLARE
  v_new_id INTEGER;
  v_max_id INTEGER;
BEGIN
  -- Test orders identity
  SELECT MAX(order_id) INTO v_max_id FROM orders;
  INSERT INTO orders (order_tms, customer_id, order_status, store_id)
    VALUES (CURRENT_TIMESTAMP, 1, 'OPEN', 1)
    RETURNING order_id INTO v_new_id;
  IF v_new_id <= v_max_id THEN
    RAISE EXCEPTION 'FAIL — New order_id % is not greater than max %', v_new_id, v_max_id;
  END IF;
  -- Clean up (need to delete order_items referencing this order first, but there shouldn't be any)
  DELETE FROM orders WHERE order_id = v_new_id;
  RAISE NOTICE 'PASS — orders identity: max was %, new id is %', v_max_id, v_new_id;
END $$;

-- =======================================================
-- PHASE 6: Behavioral Equivalence — Aggregates, joins, filters
-- =======================================================

\echo ''
\echo '--- Phase 6: Behavioral Equivalence ---'
\echo ''

-- 6.1 Verify order status distribution
\echo 'Test 6.1: Order status distribution'
DO $$
DECLARE
  v_rec RECORD;
  v_total INTEGER := 0;
BEGIN
  FOR v_rec IN
    SELECT order_status, COUNT(*) AS cnt
    FROM orders
    GROUP BY order_status
    ORDER BY order_status
  LOOP
    v_total := v_total + v_rec.cnt;
    RAISE NOTICE '  % : % orders', v_rec.order_status, v_rec.cnt;
  END LOOP;
  IF v_total <> 1950 THEN
    RAISE EXCEPTION 'FAIL — Total orders is %, expected 1950', v_total;
  END IF;
  RAISE NOTICE 'PASS — Order status distribution totals 1950';
END $$;

-- 6.2 Verify store_orders aggregation matches direct calculation
\echo 'Test 6.2: Store orders aggregation consistency'
DO $$
DECLARE
  v_view_total NUMERIC;
  v_direct_total NUMERIC;
BEGIN
  SELECT total_sales INTO v_view_total
  FROM store_orders WHERE total = 'GRAND TOTAL';

  SELECT SUM(oi.quantity * oi.unit_price) INTO v_direct_total
  FROM order_items oi;

  IF ABS(v_view_total - v_direct_total) > 0.01 THEN
    RAISE EXCEPTION 'FAIL — Grand total mismatch: view=%, direct=%', v_view_total, v_direct_total;
  END IF;
  RAISE NOTICE 'PASS — Grand total matches: %', v_view_total;
END $$;

-- 6.3 Verify product_reviews rating range
\echo 'Test 6.3: Product reviews rating range'
DO $$
DECLARE
  v_min INTEGER;
  v_max INTEGER;
BEGIN
  SELECT MIN(rating), MAX(rating) INTO v_min, v_max FROM product_reviews;
  IF v_min < 1 OR v_max > 10 THEN
    RAISE EXCEPTION 'FAIL — Ratings out of range: min=%, max=%', v_min, v_max;
  END IF;
  RAISE NOTICE 'PASS — Ratings in valid range [1-10]: min=%, max=%', v_min, v_max;
END $$;

-- 6.4 Verify JSONB queries work on product_details
\echo 'Test 6.4: JSONB querying on product_details'
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Count products that have reviews
  SELECT COUNT(*) INTO v_count
  FROM products
  WHERE product_details ? 'reviews';
  IF v_count <> 46 THEN
    RAISE EXCEPTION 'FAIL — Expected 46 products with reviews key, found %', v_count;
  END IF;

  -- Count products with a specific colour
  SELECT COUNT(*) INTO v_count
  FROM products
  WHERE product_details ->> 'colour' = 'black';
  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAIL — No products with colour black';
  END IF;

  RAISE NOTICE 'PASS — JSONB queries work: 46 products with reviews, % with colour=black', v_count;
END $$;

-- 6.5 Verify join integrity between orders and order_items
\echo 'Test 6.5: Join integrity — orders ↔ order_items'
DO $$
DECLARE
  v_orphan_count INTEGER;
BEGIN
  -- Every order_item should reference a valid order
  SELECT COUNT(*) INTO v_orphan_count
  FROM order_items oi
  LEFT JOIN orders o ON oi.order_id = o.order_id
  WHERE o.order_id IS NULL;

  IF v_orphan_count > 0 THEN
    RAISE EXCEPTION 'FAIL — % orphan order_items found', v_orphan_count;
  END IF;
  RAISE NOTICE 'PASS — No orphan order_items';
END $$;

-- 6.6 Verify all stores referenced in orders exist
\echo 'Test 6.6: Join integrity — orders ↔ stores'
DO $$
DECLARE
  v_orphan_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_orphan_count
  FROM orders o
  LEFT JOIN stores s ON o.store_id = s.store_id
  WHERE s.store_id IS NULL;

  IF v_orphan_count > 0 THEN
    RAISE EXCEPTION 'FAIL — % orders reference non-existent stores', v_orphan_count;
  END IF;
  RAISE NOTICE 'PASS — All order store references valid';
END $$;

-- =======================================================
-- Summary
-- =======================================================

\echo ''
\echo '================================================================'
\echo '  All validation tests completed successfully!'
\echo '================================================================'
\echo ''
