#!/usr/bin/env perl

# 02-extension.pl
#
# Check "RETURNING" clauses function as expected


use strict;
use warnings;

use Cwd;
use Config;
use TestLib;
use Test::More tests => 9;

use FirebirdFDWNode;
use FirebirdFDWDB;

# Initialize PostgreSQL node
# --------------------------

my $pg_node = get_new_fdw_node('pg_node');

$pg_node->init();
$pg_node->start();

my $pg_db = FirebirdFDWDB->new($pg_node);


# Prepare table
# --------------

my $table_name = 'tbl_';

foreach my $i (0..7) {
    $table_name .= chr(int(26*rand) + 97);
}


my $tbl_query = $pg_node->{dbh}->prepare(
    sprintf(
        <<EO_SQL,
CREATE TABLE %s (
  LANG_ID                         CHAR(2) NOT NULL PRIMARY KEY,
  NAME_ENGLISH                    VARCHAR(64) NOT NULL,
  NAME_NATIVE                     VARCHAR(64) NOT NULL
)
EO_SQL
        $table_name,
    ),
);

$tbl_query->execute();
$tbl_query->finish();

$pg_db->safe_psql(
    sprintf(
        <<EO_SQL,
CREATE FOREIGN TABLE %s (
  lang_id                         CHAR(2) NOT NULL,
  name_english                    VARCHAR(64) NOT NULL,
  name_native                     VARCHAR(64) NOT NULL
)
  SERVER fb_test
  OPTIONS (table_name '%s')
EO_SQL
        $table_name,
        $table_name,
    ),
);


# 1. INSERT ... RETURNING ... with specified columns
# ==================================================

my $insert_q = sprintf(
    <<EO_SQL,
INSERT INTO %s (lang_id, name_english, name_native)
     VALUES ('de', 'German', 'Deutsch')
  RETURNING lang_id, name_native
EO_SQL
    $table_name,
);

my $out = $pg_db->safe_psql( $insert_q );


is(
	$out,
	'de|Deutsch',
	q|'INSERT ... RETURNING' with specified columns OK|,
);


# 2. INSERT ... RETURNING ... with all columns
# ============================================

$insert_q = sprintf(
    <<EO_SQL,
INSERT INTO %s (lang_id, name_english, name_native)
     VALUES ('sv', 'Swedish', 'svenska')
  RETURNING *
EO_SQL
    $table_name,
);


$out = $pg_db->safe_psql( $insert_q );

is(
	$out,
	qq/sv|Swedish|svenska/,
	q|'INSERT ... RETURNING' all columns OK|,
);


# 3. INSERT ... RETURNING ... with multiple rows
# ==============================================

$insert_q = sprintf(
    <<EO_SQL,
WITH result AS (
  INSERT INTO %s (lang_id, name_english, name_native)
       VALUES ('nl', 'Dutch', 'Nederlands'),
              ('da', 'Danish', 'Dansk')
    RETURNING name_native, lang_id
)
SELECT * FROM result ORDER BY lang_id
EO_SQL
    $table_name,
);

$out = $pg_db->safe_psql( $insert_q );


is(
	$out,
	qq/Dansk|da\nNederlands|nl/,
	q|'INSERT ... RETURNING' with multiple rows OK|,
);


# 4. UPDATE ... RETURNING ... with specified columns
# ==================================================

my $update_q = sprintf(
    <<EO_SQL,
   UPDATE %s SET name_native = 'wibblska'
    WHERE lang_id = 'sv'
RETURNING lang_id, name_native
EO_SQL
    $table_name,
);

$out = $pg_db->safe_psql( $update_q );

is(
	$out,
	qq/sv|wibblska/,
	q|'UPDATE ... RETURNING' with specified columns OK|,
);


# 5. UPDATE ... RETURNING ... with all columns
# ============================================

$update_q = sprintf(
    <<EO_SQL,
   UPDATE %s SET name_native = 'Wibblisch'
    WHERE lang_id = 'de'
RETURNING *
EO_SQL
    $table_name,
);


$out = $pg_db->safe_psql( $update_q );

is(
	$out,
	qq/de|German|Wibblisch/,
	q|'UPDATE ... RETURNING *' OK|,
);


# 6. UPDATE ... RETURNING ... with multiple rows
# ==============================================

$update_q = sprintf(
    <<EO_SQL,
WITH result AS (
     UPDATE %s SET name_native = name_native || ' (maybe)'
      WHERE lang_id IN ('de', 'sv')
  RETURNING name_native, lang_id
)
SELECT * FROM result ORDER BY lang_id
EO_SQL
    $table_name,
);

$out = $pg_db->safe_psql( $update_q );

is(
	$out,
	qq/Wibblisch (maybe)|de\nwibblska (maybe)|sv/,
	q|'UPDATE ... RETURNING' with multiple rows OK|,
);


# 7. DELETE ... RETURNING ... with specified columns
# ==================================================

my $delete_q = sprintf(
    <<EO_SQL,
   DELETE FROM %s
    WHERE lang_id = 'sv'
RETURNING lang_id, name_native
EO_SQL
    $table_name,
);

$out = $pg_db->safe_psql( $delete_q );

is(
	$out,
	qq/sv|wibblska (maybe)/,
	q|'DELETE ... RETURNING' with specified columns OK|,
);

# 8. DELETE ... RETURNING ... with all columns
# ============================================

$delete_q = sprintf(
    <<EO_SQL,
   DELETE FROM %s
    WHERE lang_id = 'de'
RETURNING *
EO_SQL
    $table_name,
);


$out = $pg_db->safe_psql( $delete_q );

is(
	$out,
	qq/de|German|Wibblisch (maybe)/,
	q|'DELETE ... RETURNING *' OK|,
);

# 9. DELETE ... RETURNING ... with multiple rows
# ==============================================

$delete_q = sprintf(
    <<EO_SQL,
WITH result AS (
     DELETE FROM %s
      WHERE lang_id IN ('da', 'nl')
  RETURNING name_native, lang_id
)
SELECT * FROM result ORDER BY lang_id
EO_SQL
    $table_name,
);

$out = $pg_db->safe_psql( $delete_q );

is(
	$out,
	qq/Dansk|da\nNederlands|nl/,
	q|'DELETE ... RETURNING' with multiple rows OK|,
);


# Clean up
# --------

my $drop_foreign_server = q|DROP SERVER IF EXISTS fb_test CASCADE|;

$pg_db->safe_psql( $drop_foreign_server );

$pg_node->firebird_reconnect();

my $drop_table = sprintf(
    q|DROP TABLE %s|,
    $table_name,
);

$tbl_query = $pg_node->{dbh}->prepare( $drop_table );

$tbl_query->execute();
$tbl_query->finish();


done_testing();
