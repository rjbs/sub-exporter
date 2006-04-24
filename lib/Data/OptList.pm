
package Data::OptList;
use strict;
use warnings;

=head1 NAME

Data::OptList - parse and validate simple name/value option pairs

=head1 VERSION

version 0.01

  $Id$

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use Data::OptList;

  my $options = Data::Optlist::canonicalize_opt_list([
    qw(key1 key2 key3 key4),
    key5 => { ... },
    key6 => [ ... ],
    key7 => sub { ... },
    key8 => { ... },
    key8 => [ ... ],
  ]);

...is the same thing, more or less, as:

  my $options = [
    [ key1 => undef,        ],
    [ key2 => undef,        ],
    [ key3 => undef,        ],
    [ key4 => undef,        ],
    [ key5 => { ... },      ],
    [ key6 => [ ... ],      ],
    [ key7 => sub { ... },  ],
    [ key8 => { ... },      ],
    [ key8 => [ ... ],      ],
  ]);

=head1 DESCRIPTION

Hashes are great for storing named data, but if you want more than one entry
for a name, you have to use a list of pairs.  Even then, this is really boring
to write:

  @values = (
    foo => undef,
    bar => undef,
    baz => undef,
    xyz => { ... },
  );

Just look at all those undefs!  Don't worry, we can get rid of those:

  @values = (
    map { $_ => undef } qw(foo bar baz),
    xyz => { ... },
  );

Aaaauuugh!  We've saved a little typing, but now it requires thought to read,
and thinking is even worse than typing.

With Data::OptList, you can do this instead:

  Data::OptList::canonicalize_opt_list([
    qw(foo bar baz),
    xyz => { ... },
  ]);

This works by assuming that any defined scalar is a name and any reference
following a name is its value.

=cut

use Scalar::Util ();

=head1 FUNCTIONS

=head2 canonicalize_opt_list

B<Warning>: This modules presently exists only to serve Sub::Exporter.  Its
interface is still subject to change at the author's whim.

  my $opt_list = Data::OptList::canonicalize_opt_list(
    $input,
    $moniker,
    $require_unique,
    $must_be,
  );

This produces an array of arrays; the inner arrays are name/value pairs.
Values will be either "undef" or a reference.

Valid inputs:

 undef    -> []
 hashref  -> [ [ key1 => value1 ] ... ] # non-ref values become undef
 arrayref -> every value followed by a ref becomes a pair: [ value => ref   ]
             every value followed by undef becomes a pair: [ value => undef ]
             otherwise, it becomes [ value => undef ] like so:
             [ "a", "b", [ 1, 2 ] ] -> [ [ a => undef ], [ b => [ 1, 2 ] ] ]

C<$moniker> is a name describing the data, which will be used in error
messages.

If C<$require_unique> is true, an error will be thrown if any name is given
more than once.

C<$must_be> is either a scalar or array of scalars; it defines what kind(s) of
refs may be values.  If an invalid value is found, an exception is thrown.  If
no value is passed for this argument, any reference is valid.

=cut

sub canonicalize_opt_list {
  my ($opt_list, $moniker, $require_unique, $must_be) = @_;

  return [] unless $opt_list;

  $opt_list = [
    map { $_ => (ref $opt_list->{$_} ? $opt_list->{$_} : ()) } keys %$opt_list
  ] if ref $opt_list eq 'HASH';

  my @return;
  my %seen;

  for (my $i = 0; $i < @$opt_list; $i++) {
    my $name = $opt_list->[$i];
    my $value;

    if ($require_unique) {
      Carp::croak "multiple definitions provided for $name" if $seen{$name}++;
    }

    if    ($i == $#$opt_list)             { $value = undef;            }
    elsif (not defined $opt_list->[$i+1]) { $value = undef; $i++       }
    elsif (ref $opt_list->[$i+1])         { $value = $opt_list->[++$i] }
    else                                  { $value = undef;            }

    if ($must_be and defined $value) {
      my $ref = Scalar::Util::reftype($value);
      my $ok  = ref $must_be ? (grep { $ref eq $_ } @$must_be)
              :                ($ref eq $must_be);

      Carp::croak "$ref-ref values are not valid in $moniker opt list" if !$ok;
    }

    push @return, [ $name => $value ];
  }

  return \@return;
}

=head2 expand_opt_list

  my $opt_hash = Data::OptList::expand_opt_list($input, $moniker, $must_be);

Given valid C<expand_opt_list> input, return a hash.

=cut

sub expand_opt_list {
  my ($opt_list, $moniker, $must_be) = @_;
  return {} unless $opt_list;
  # return $opt_list if ref $opt_list eq 'HASH';

  $opt_list = canonicalize_opt_list($opt_list, $moniker, 1, $must_be);
  my %hash = map { $_->[0] => $_->[1] } @$opt_list;
  return \%hash;
}

1;
