#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Tie::Hash::Expire;

# Reimplementation of sum() so that we don't have to depend on List::Util.
sub sum(@)
{
    my $sum = 0;

    $sum += $_ for @_;

    return $sum;
}

# A closure to make manual time manipulation a bit easier.
sub my_time_closure
{
    my $my_time = 0;

    return sub
    {
        my ($add) = @_;

        if (defined $add)
        {
            $my_time += $add;
        }

        return $my_time;
    };
}

my %num_tests;

# Exercises STORE and FETCH without expiry.
$num_tests{basic_no_expiry} = 1;
sub basic_no_expiry
{
    my $f = my_time_closure();
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => undef;
    
    $foo{a} = 'bar';
    $f->(1_000);
    is($foo{a}, 'bar', 'Undefined LIFETIME');
}

# Exercises STORE and FETCH with simple expiry.
$num_tests{basic_expiry} = 2;
sub basic_expiry
{
    my $f = my_time_closure();
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => 4;

    $foo{a} = 'bar';
    $f->(2);
    is($foo{a}, 'bar', 'Defined LIFETIME, pre-expiry (simple)');
    $f->(2);
    ok(!exists $foo{a}, 'Defined LIFETIME, post-expiry (simple)');
}

# Exercises STORE and FETCH while resetting values.
$num_tests{expiry_reset} = 3;
sub expiry_reset
{
    my $f = my_time_closure();
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => 8;

    $foo{a} = 'bar';
    $f->(7);
    is($foo{a}, 'bar', 'Defined LIFETIME, pre-expiry');
    $foo{a} = 'baz';
    $f->(7);
    is($foo{a}, 'baz', 'Defined LIFETIME, post-reset');
    $f->(1);
    ok(!exists $foo{a}, 'Defined LIFETIME, post-expiry');
}

# Exercises STORE and FETCH while resetting values, with multiple elements.
$num_tests{expiry_reset_multiple} = 5;
sub expiry_reset_multiple
{
    my $f = my_time_closure();
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => 8;

    $foo{a} = 'bar';
    $foo{b} = 'baz';
    $f->(4);
    $foo{b} = 'qux';
    $f->(3);
    is($foo{a}, 'bar', 'Defined LIFETIME, pre-expiry (multiple #1)');
    is($foo{b}, 'qux', 'Defined LIFETIME, pre-expiry (multiple #2)');
    $f->(2);
    ok(!exists $foo{a}, 'Defined LIFETIME, post-expiry (multiple #1)');
    ok(exists $foo{b}, 'Defined LIFETIME, near-expiry (multiple #2)');
    $f->(4);
    ok(!exists $foo{b}, 'Defined LIFETIME, post-expiry (multiple #2)');
}

# Exercises FIRSTKEY with expiry before NEXTKEY.
$num_tests{expiry_firstkey_nextkey} = 1;
sub expiry_firstkey_nextkey
{
    my $f = my_time_closure();
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => 4;

    $foo{a} = 1;
    $foo{b} = 2;

    $f->(3);
    my $first_key = (each %foo)[0];
    $f->(1);
    my $second_key = (each %foo)[0];

    is($second_key, undef, 'Expiry between FIRSTKEY and NEXTKEY');
}

plan tests => sum(values %num_tests);

basic_no_expiry();
basic_expiry();
expiry_reset();
expiry_reset_multiple();
expiry_firstkey_nextkey();
