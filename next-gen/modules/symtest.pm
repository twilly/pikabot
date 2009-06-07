#!/usr/bin/perl -w
package symtest;
# symtest.pm: Collection of things to do with symbol tables all
#             organized and pretty-like.
#
# Copyright (C) 2009  Justin Lee  < kool.name at gmail.com >
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
###
# To do:
#
#   2009-04-22:
#     - Get a better name for this package.
#     - (DROP 2009-04-29) Add types 'IO' and 'GLOB' to "%TYPE".
###
# History:
#
#   2009-04-29:
#     - Updated the over all "flow" of "synthesize" to be less
#       dumb.  It could use more comments, but whatever.
#     - Combined "symbol_exists" and "symbol_ref" into
#       the *cough*superior*cough* "synthesize" routine.
#   2009-04-22:
#     - Fixed bug in calls to "%TYPE".
#     - Coded initial crap.


use strict;
use warnings;



# Methods provided by the symtest package, none are
# exported by default.

sub synthesize ($;$$) {
  # This routine is candidate for optimization! :D
  #
  # symtest::synthesize() is a combination of the
  # first two routines that were included in this
  # package.
  # The first was a symbol tester which
  # could test a symbol table, item, or specific
  # item type for definedness or existence.
  # The second was a routine which returned a
  # reference to a symbol table given it's package
  # name.
  # I've combined them such that it returns a ref
  # to whatever is wanted if it's found or undefined
  # if it is not.
  #
  # Examples:
  #
  #
  #   Get a parent's entire "xdcc" symbol as a reference:
  #
  #     my $par_xdcc_ref = synthesize(scalar(caller), 'xdcc') or die;
  #     # Get at references you can use:
  #     my $xdcc = *$par_xdcc_ref{CODE}; # note the * and {TYPE}
  #     my $xdcc2 = \&{$par_xdcc_ref}; # option two (use &, @, %, $, etc)
  #     $xdcc->do('blah');
  #     $xdcc2->do('blah'); # same as above
  #     # To get right to the point use something like:
  #     print &{*$par_xdcc_ref{CODE}}; # must match {TYPE} and (&, @, %, etc)
  #
  #
  #   Easily get a reference to my symbol table for parsing:
  #
  #     my $stab = synthesize(__PACKAGE__) or die;
  #     # Parse $stab for it's subroutines:
  #     print "$_\n" foreach grep { defined(&{$stab->{$_}}) } keys(%{$stab});
  #
  #
  #   Check that hash "info" exists somewhere in the 'main' package:
  #
  #     die 'Missing required data' unless synthesize('', 'info', 'HASH');
  #     # Values returned by this can be manipulated like good ol' standard
  #     # refs that you are used to:
  #     my $h = synthesize(scalar(caller), 'darray', 'ARRAY') or die;
  #     push(@{$h}, 'new val') or die; # this is dangerous, best add a `die()`
  #     print $h->[666];
  #
  #
  #   Bonus round:
  #
  #     # For anything that returns a package name, say... like in Pikabot! :D
  #     my ($s) = _custom_require join('/', BASE_DIR, shift);
  #     synthesize($s) or die 'Package does not seem to have a symbol table';
  #     foreach my $r (REQUIRED_CRAP) {
  #       synthesize($s, $r->{'name'}, $r->{'type'}) or die "Missing valid $r->{'name'}";
  #     }
  #
  #
  # This is not everything you can do with this "breakout" module, see
  # < http://www252.pair.com/comdog/mastering_perl/Chapters/08.symbol_tables.html > for
  # some other ideas.

  my ($table, $symbol, $type) = @_;
  my $ref;


  # Check table:
  eval sprintf(
    'defined(%%%s::) or die;',
    $table,
  );
  $@ and do {

    return (undef);
  };


  defined($symbol) and do {

    # Check symbol:
    eval sprintf(
      'exists($%s::{%s}) or die;',
      $table,
      $symbol,
    );
    $@ and do {

      return (undef);
    };


    defined($type) and do {

      # Check type:
      eval sprintf(
        # This check has a small caveat in that it can only
        # check if a certain type is defined, so:
        #   our ($start); synthesize('', 'start', 'SCALAR') or die;
        # Will fail horribly. :D
        'defined(*{$%s::{%s}}{%s}) or die;',
        # The above could be replaced with `ref( .... ) or die;` for
        # more strict control over what the user can ask for... BUT
        # as it stands there's no reason to do that.
        $table,
        $symbol,
        uc($type), # yeah, that's right
      );
      eval sprintf(
        '$ref = *{$%s::{%s}}{%s};', # no check for ref()
        $table,
        $symbol,
        uc($type),
      );
      $@ and do {

        return (undef);
      };

      return ($ref);
    };


    eval sprintf(
      '$ref = \\$%s::{%s}; ref($ref) or die;',
      $table,
      $symbol,
    );
    $@ and do {

      return (undef);
    };

    return ($ref);
  };


  eval sprintf(
    '$ref = \\%%%s::; ref($ref) or die;',
    $table,
  );
  $@ and do {

    return (undef);
  };

  return ($ref);
}


our (@ISA, @EXPORT_OK);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);

  eval sprintf(<<'__END__', __PACKAGE__, __PACKAGE__);

    foreach my $s (keys(%%%s::)) {
      defined(&{$%s::{$s}}) or do {

        next;
      };

      push(@EXPORT_OK, $s);
    }

    # The __END__ MUST and I repeat *MUST* be located right after your
    # system's newline or confusion and destruction will ensue... And
    # not the fun kind, either.

__END__


  $@ and do {

    die;
  };
}


__PACKAGE__;