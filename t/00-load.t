#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tie::Hash::Expire' );
}

diag( "Testing Tie::Hash::Expire $Tie::Hash::Expire::VERSION, Perl $], $^X" );
