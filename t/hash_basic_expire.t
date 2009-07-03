#!/usr/bin/perl -w

use strict;

use Test::More;
use Tie::Hash::Expire;

# Reimplementation of sum() so that we don't have to depend on List::Util.
sub sum(@)
{
    my $sum = 0;

    $sum += $_ for @_;

    return $sum;
}

our %num_tests;

# Tests various hash instantiation methods.
$num_tests{basic_args} = 2;
sub basic_args
{
    my %foo;
    eval
    {
        tie %foo => 'Tie::Hash::Expire', LIFETIME => 2;
    };

    is($@, q{}, 'Basic creation with LIFETIME');

    my %bar;
    eval
    {
        tie %bar => 'Tie::Hash::Expire', LIFETIME => 2, TIMEFUNC => sub {};
    };

    is($@, q{}, 'Basic creation with TIMEFUNC');
}

# Tests FETCH on undefined values.
$num_tests{basic_fetch_undef} = 1;
sub basic_fetch_undef
{
    tie my %foo => 'Tie::Hash::Expire', LIFETIME => 1;

    $foo{a} = 1;

    is($foo{b}, undef, 'Basic FETCH with undefined value');
}

# Tests STORE+FETCH and EXISTS on undefined values.
$num_tests{basic_store_exists_undef} = 2;
sub basic_store_exists_undef
{
    tie my %foo => 'Tie::Hash::Expire', LIFETIME => 1;

    $foo{a} = undef;

    ok(exists $foo{a}, 'Basic EXISTS with undefined value');
    is($foo{a}, undef, 'Basic FETCH with undefined value');
}

plan tests => sum(values %num_tests);

basic_args();
basic_fetch_undef();
basic_store_exists_undef();
