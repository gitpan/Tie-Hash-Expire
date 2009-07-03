package Tie::Hash::Expire;

use warnings;
use strict;

use base 'Tie::Hash';

use Carp;

=head1 NAME

Tie::Hash::Expire - A tied hash object with key-value pairs that expire.

=head1 SYNOPSIS

    use Tie::Hash::Expire;

    # Use the default time() function from the system or from Time::HiRes if
    # that module is available.
    tie my %foo => 'Tie::Hash::Expire', LIFETIME => 10;
    $foo{bar} = 1;
    sleep(10);
    # $foo{bar} no longer exists.

    # Explicitly do not try to import Time::HiRes::time().
    tie my %bar => 'Tie::Hash::Expire', HIRES => 0, LIFETIME => 10;

    # Use a manual, counter-style time function.
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
    my $f = my_time_closure();
    tie my %baz => 'Tie::Hash::Expire', TIMEFUNC => $f, LIFETIME => 10;
    $bar{a} = 1;
    $f->(9);
    # $bar{a} still exists.
    $f->(1);
    # $bar{a} no longer exists.

    # If you don't specify a LIFETIME or if your LIFETIME is <= 0, then you
    # just get an ordinary (i.e. not tied to anything) hash back.
    tie my %qux => 'Tie::Hash::Expire', LIFETIME => 0;
    # %qux is just an empty list: ().

=cut

our $VERSION = '0.01';

sub _is_expired
{
    my ($self, $key) = @_;

    return exists $self->{HASH}->{$key} &&
           $self->{EXPIRE}->{$key} <= $self->{TIMEFUNC}->();
}

sub _delete
{
    my ($self, $key) = @_;

    delete $self->{HASH}->{$key};
    delete $self->{EXPIRE}->{$key};
}

sub _update_cache
{
    my ($self, $key) = @_;

    if ($self->_is_expired($key))
    {
        $self->_delete($key);
    }
}

sub _next_key
{
    my ($self) = @_;

    while (my $key = each(%{$self->{HASH}}))
    {
        if ($self->_is_expired($key))
        {
            $self->_delete($key);
        }
        else
        {
            return $key;
        }
    }

    return undef;
}

=head1 METHODS

=cut

=head2 TIEHASH

Creates the hash, with an optional LIFETIME parameter.  If LIFETIME is
undefined or zero, you would be better off using an ordinary hash instead
of this fancy, tied type; however, this module will play along, anyway.

=cut
sub TIEHASH
{
    my ($self, %args) = @_;

    my $hires = defined $args{HIRES} ? $args{HIRES} : 1;
    my $timefunc = $args{TIMEFUNC};

    # Only bother defining a timefunc if the user didn't supply one.
    if (!defined $timefunc)
    {
        # Check to see if we should consider Time::HiRes.
        if ($hires)
        {
            eval
            {
                require Time::HiRes;
            };

            # Define a new $timefunc using Time::HiRes.
            if (!$@)
            {
                Time::HiRes->import('time');
                $timefunc = sub() { return Time::HiRes::time(); };
            }
        }

        # We didn't get a $hires function; use the core time().
        if (!defined $timefunc)
        {
            $timefunc = sub() { return time(); };
        }
    }

    if (!defined $args{LIFETIME} || $args{LIFETIME} <= 0)
    {
        # Just use a real hash, will you?  It'll be faster!
        return {};
    }

    my %node =
    (
        LIFETIME        => $args{LIFETIME},
        HASH            => {},
        EXPIRE          => {},
        TIMEFUNC        => $timefunc,
    );

    return bless \%node, $self;
}

=head2 FETCH

Returns the value corresponding to a key.  If the key does not exist in the
underlying hash, returns undef.

=cut
sub FETCH
{
    my ($self, $key) = @_;

    return exists $self->{HASH}->{$key} ? $self->{HASH}->{$key} : undef;
}

=head2 STORE

Stores a key-value pair in the underlying hash.  Sets the expiry time to the
current time plus LIFETIME.  If the key had previously been scheduled for
deletion, unschedules it.

=cut
sub STORE
{
    my ($self, $key, $value) = @_;

    $self->{HASH}->{$key} = $value;
    $self->{EXPIRE}->{$key} = $self->{TIMEFUNC}->() + $self->{LIFETIME};
}

=head2 EXISTS

Returns a true value if the key exists in the underlying hash or false if the
key does not exist in the underlying hash.

=cut
sub EXISTS
{
    my ($self, $key) = @_;

    return exists $self->{HASH}->{$key};
}

=head2 CLEAR

Resets the underlying hash and all expiry times.  Also removes all scheduled
deletion records.

=cut
sub CLEAR
{
    my ($self) = @_;

    $self->{HASH} = {};
    $self->{EXPIRE} = {};
}

=head2 DELETE

Deletes a key-value pair from the underlying hash.

=cut
sub DELETE
{
    my ($self, $key) = @_;

    $self->_delete($key);
}

=head2 SCALAR

Returns the scalar value of the underlying hash.

=cut
sub SCALAR
{
    my ($self) = @_;

    return scalar %{$self->{HASH}};
}

=head2 FIRSTKEY

Returns the first key in the hash, for iterative purposes.

=cut
sub FIRSTKEY
{
    my ($self) = @_;

    # Reset internal iterator.
    my $a = keys %{$self->{HASH}};

    return $self->_next_key();
}

=head2 NEXTKEY

Returns the next key in the hash, using the iterator first assigned in
FIRSTKEY() or later reassigned in a previous NEXTKEY() call as a basis for
search.

=cut
sub NEXTKEY
{
    # Perl is kind enough to give us last_key as the second argument, but we
    # don't need it here.
    my ($self, undef) = @_;

    return $self->_next_key();
}

# Integrate cache expiry via the symbol table.
for my $f qw(FETCH EXISTS)
{
    eval qq
    {
        *Tie::Hash::Expire::_uncached_$f = *Tie::Hash::Expire::$f;
        undef *Tie::Hash::Expire::$f;
        *Tie::Hash::Expire::$f = sub
        {
            \$_[0]->_update_cache(\$_[1]);
            &_uncached_$f;
        };
    };
}

=head1 CAVEATS

If the user does not explicitly provide a function for TIMEFUNC, this module
will use the Perl time() function to determine whether a key-value pair is
expired.  This means that any oddities in the system clock may unexpectedly
affect the performance of this module.  In particular, if a service such as
NTP regularly sets the system time and happens to frequently compensate for
significant clock drift, unexpected results will definitely occur.

This module will attempt to use the time() from Time::HiRes if that module can
be found.  Otherwise, it will fall back to the core Perl time() function,
which does not provide sub-second accuracy.

Tie::Hash::Expire does not inherently understand the concept of a non-expiring
hash; however, if it's absolutely necessary to implement one of these with
Tie::Hash::Expire, a TIMEFUNC that returns a constant could be used.

=head1 AUTHOR

Colin Wetherbee <cww@cpan.org>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-tie-hash-expire at rt.cpan.org>, or through
the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tie-Hash-Expire>.  I will
be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tie::Hash::Expire

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tie-Hash-Expire>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Tie-Hash-Expire>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Tie-Hash-Expire>

=item * Search CPAN

L<http://search.cpan.org/dist/Tie-Hash-Expire>

=back

=head1 COPYRIGHT

Copyright (c) 2009 Colin Wetherbee

=head1 LICENSE

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=cut

1;
