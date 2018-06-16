package FirebirdFDWNode;

# This class extends PostgresNode with firebird_fdw-specific methods.
#
# It has two main purposes:
#  1) to initialise a PostgreSQL node with the firebird_fdw extension
#     configured
#  2) to provide a connection to a running Firebird instance.
#
# The Firebird database must be specified with the standard Firebird
# environment variables `ISC_DATABASE`, `ISC_USER` and `ISC_PASSWORD`.
#
# XXX behaviour undefined if not set

use strict;
use warnings;

use base 'PostgresNode';
use v5.10.0;

use PostgresNode;

use Exporter 'import';
use vars qw(@EXPORT @EXPORT_OK);

use Carp 'verbose';

use DBI;

$SIG{__DIE__} = \&Carp::confess;

@EXPORT = qw(
	get_new_fdw_node
);

sub get_new_fdw_node
{
	my $name = shift;

	my $class = 'FirebirdFDWNode';

	my $self = $class->SUPER::get_new_node($name);

	$self->{firebird_dbname} = $ENV{'ISC_DATABASE'};

	$self->{dbh} = DBI->connect(
		"dbi:Firebird:host=localhost;dbname=".$self->{firebird_dbname},
		undef,
		undef,
		{
			PrintError => 1,
			RaiseError => 1,
			AutoCommit => 1
		}
	);

	return $self;
}


sub firebird_reconnect {
    my $self = shift;

    $self->{dbh}->disconnect();

	$self->{dbh} = DBI->connect(
		"dbi:Firebird:host=localhost;dbname=".$self->{firebird_dbname},
		undef,
		undef,
		{
			PrintError => 1,
			RaiseError => 1,
			AutoCommit => 1
		}
	);
}

1;
