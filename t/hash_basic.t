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

my %num_tests;

# Exercises SCALAR.
$num_tests{basic_scalar} = 3;
sub basic_scalar
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    is(scalar(%foo), '0', 'Basic SCALAR: zero elements');

    $foo{a} = 'bar';

    like(scalar(%foo), qr|^1/|, 'Basic SCALAR: one element');

    $foo{b} = 'baz';

    like(scalar(%foo), qr|^2/|, 'Basic SCALAR: two elements');
}

# Exercises STORE and FETCH.
$num_tests{basic_store_fetch} = 1 + 3 + 1 + 3;
sub basic_store_fetch
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    for (my $i = 0; $i < 3; ++$i)
    {
        $foo{$i} = $i + 1;
    }

    like(scalar(%foo), qr|^3/|, 'Basic STORE: three elements');

    for (my $i = 0; $i < 3; ++$i)
    {
        is($foo{$i}, $i + 1, "Basic FETCH: element $i");
    }

    like(scalar(%foo), qr|^3/|, 'Basic STORE: three elements after FETCH');

    $foo{a} = 'bar';

    is($foo{a}, 'bar', 'Basic FETCH: very basic');

    $foo{a} = 'baz';

    is($foo{a}, 'baz', 'Basic FETCH: overwrite');

    $foo{a} = 'quuuux';

    is($foo{a}, 'quuuux', 'Basic FETCH: overwrite longer');
}

# Exercises EXISTS.
$num_tests{basic_exists} = 3;
sub basic_exists
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    ok(!exists $foo{a}, 'Basic EXISTS: new hash');

    $foo{a} = 'bar';

    ok(exists $foo{a}, 'Basic EXISTS: existent element');
    ok(!exists $foo{b}, 'Basic EXISTS: non-existent element');
}

# Exercises DELETE.
$num_tests{basic_delete} = 3 + 1;
sub basic_delete
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    for (my $i = 0; $i < 3; ++$i)
    {
        $foo{$i} = $i + 1;
    }

    for (my $i = 0; $i < 3; ++$i)
    {
        delete $foo{$i};
        is($foo{$i}, undef, "Basic DELETE: element $i");
    }

    is(scalar(%foo), 0, 'Basic complete DELETE test');
}

# Exercises DELETE and EXISTS.
$num_tests{basic_delete_exists} = 6 + 1;
sub basic_delete_exists
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    $foo{a} = 'bar';
    $foo{b} = 'baz';

    ok(exists $foo{a},
       'Basic DELETE+EXISTS: existent element "a" (zero non-existent)');
    ok(exists $foo{b},
       'Basic DELETE+EXISTS: existent element "b" (zero non-existent)');

    delete $foo{a};
    
    ok(!exists $foo{a},
       'Basic DELETE+EXISTS: non-existent element "a" (one non-existent)');
    ok(exists $foo{b},
       'Basic DELETE+EXISTS: existent element "b" (one non-existent)');

    delete $foo{b};
    
    ok(!exists $foo{a},
       'Basic DELETE+EXISTS: non-existent element "a" (both non-existent)');
    ok(!exists $foo{b},
       'Basic DELETE+EXISTS: non-existent element "b" (both non-existent)');

    is(scalar(%foo), 0, 'Basic complete DELETE+EXISTS test');
}

# Exercises CLEAR.
$num_tests{basic_clear} = 2;
sub basic_clear
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    $foo{a} = 1;
    $foo{b} = 2;

    eval
    {
        %foo = ();
    };

    is($@, q{}, 'Basic CLEAR exception test');
    is(scalar(%foo), 0, 'Basic CLEAR scalar test');
}

# Exercises FIRSTKEY and NEXTKEY.
$num_tests{basic_firstkey_nextkey} = 1;
sub basic_firstkey_nextkey
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    my $num_high = 16;

    for (my $i = 0; $i < $num_high; ++$i)
    {
        $foo{$i} = $i * 2;
    }

    my @nums = (0 .. $num_high - 1);

    for my $key (keys %foo)
    {
        for (my $i = 0; $i < scalar(@nums); ++$i)
        {
            if ($nums[$i] == $key)
            {
                splice(@nums, $i, 1);
                last;
            }
        }
    }

    is(scalar(@nums), 0, 'Basic fill/purge with verify for FIRSTKEY+NEXTKEY');
}

# Exercises FIRSTKEY, NEXTKEY, and DELETE via each().
$num_tests{basic_each} = 9;
sub basic_each
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    my $num_high = 8;

    for (my $i = 0; $i < $num_high; ++$i)
    {
        $foo{$i} = $i * 2;
    }

    my $i = 0;
    while (my $key = each %foo)
    {
        is($foo{$key}, $key * 2, "Basic each(): $i");
        delete $foo{$key};
        ++$i;
    }

    is(scalar(%foo), 0, 'Basic each() scalar test');
}

# Exercises NEXTKEY with DELETE before FETCH.
$num_tests{basic_nextkey_delete_before} = 1;
sub basic_nextkey_delete_before
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    $foo{a} = 1;
    $foo{b} = 2;

    my $first_key = (each %foo)[0];

    delete $foo{$first_key eq 'a' ? 'b' : 'a'};

    my $second_key = (each %foo)[0];

    is($second_key, undef, 'Basic each() with DELETE before FETCH.');
}

# Exercises NEXTKEY with DELETE after FETCH.
$num_tests{basic_nextkey_delete_after} = 1;
sub basic_nextkey_delete_after
{
    tie my %foo => 'Tie::Hash::Expire', TIMEFUNC => sub { 1 }, LIFETIME => 2;

    $foo{a} = 1;
    $foo{b} = 2;

    my $first_key = (each %foo)[0];

    delete $foo{$first_key eq 'a' ? 'a' : 'b'};

    my $second_key = (each %foo)[0];

    is($second_key, $first_key eq 'a' ? 'b' : 'a',
       'Basic each() with DELETE after FETCH.');
}

plan tests => sum(values %num_tests);

basic_scalar();
basic_store_fetch();
basic_exists();
basic_delete();
basic_delete_exists();
basic_clear();
basic_firstkey_nextkey();
basic_each();
basic_nextkey_delete_before();
basic_nextkey_delete_after();
