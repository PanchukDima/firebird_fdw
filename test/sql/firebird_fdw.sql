/*
 * Regression test for firebird_fdw
 */

SET client_min_messages = WARNING;

CREATE EXTENSION firebird_fdw;

CREATE FOREIGN DATA WRAPPER firebird
  HANDLER firebird_fdw_handler
  VALIDATOR firebird_fdw_validator;

CREATE SERVER firebird_fdw_test
  FOREIGN DATA WRAPPER firebird
  OPTIONS (
    address 'localhost',
    database '/tmp/firebird_fdw.fdb'
 );

CREATE USER MAPPING
  FOR CURRENT_USER
  SERVER firebird_fdw_test
  OPTIONS(
    username 'sysdba',
    password 'masterkey'
  );

CREATE FOREIGN TABLE test1 (
  id INT
)
SERVER firebird_fdw_test;

INSERT INTO test1 VALUES(1);
SELECT * FROM test1;

