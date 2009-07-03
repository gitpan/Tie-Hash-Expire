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

my %num_tests;

# Exercises explicitly using the system time().
$num_tests{tiehash_explicit_time} = 1;
sub tiehash_explicit_time
{
    my $realtime = sub { return time() };
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => $realtime, LIFETIME => 1;

    $foo{a} = 1;
    sleep(1);
    is($foo{a}, undef, 'Expiry with explicit time()');
}

# Exercises implicitly using the system time().
$num_tests{tiehash_implicit_time} = 1;
sub tiehash_implicit_time
{
    tie my %foo => 'Tie::Hash::Expire', LIFETIME => 1;

    $foo{a} = 1;
    sleep(1);
    is($foo{a}, undef, 'Expiry with implicit time()');
}

# Exercises explicitly not using Time::HiRes.
$num_tests{tiehash_explicit_nohires} = 1;
sub tiehash_explicit_nohires
{
    tie my %foo => 'Tie::Hash::Expire', LIFETIME => 1, HIRES => 0;

    $foo{a} = 1;
    sleep(1);
    is($foo{a}, undef, 'Expiry with explicit no Time::HiRes');
}

# Exercises explicitly using Time::HiRes, if it exists.
$num_tests{tiehash_explicit_hires} = 1;
sub tiehash_explicit_hires
{
    SKIP:
    {
        eval
        {
            require Time::HiRes;
        };

        if ($@)
        {
            skip 'No Time::HiRes available; unable to test it.',
                 $num_tests{tiehash_explicit_hires};
        }

        Time::HiRes->import('time');
        Time::HiRes->import('sleep');

        my $realtime = sub { return Time::HiRes::time(); };
        tie my %foo => 'Tie::Hash::Expire', LIFETIME => 0.5,
                                            TIMEFUNC => $realtime;

        $foo{a} = 1;
        Time::HiRes::sleep(0.5);
        is($foo{a}, undef, 'Expiry with explicit Time::HiRes');
    }
}

plan tests => sum(values %num_tests);

tiehash_explicit_time();
tiehash_implicit_time();
tiehash_explicit_nohires();
tiehash_explicit_hires();
