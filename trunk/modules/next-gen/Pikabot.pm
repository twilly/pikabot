#!/usr/bin/perl -w
package Pikabot;
# Pikabot: The cutest bot you've ever seen.
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
#   2009-04-16:
#     - Add checks to "spawn" method.
#   2009-04-14:
#     - Add checks to "ike" method.
#   2009-04-11:
#     - Replace spawn checks/config with call to $main::VERSION and
#       %main::IRSSI?  Problems might occur if this module is nested...
#   2009-04-07:
#     - (DROP 2009-04-16) Simplify configuration a little (E.G: For global channels,
#       allow scalar values to be pushed onto the stack.)
#     - (DROP 2009-04-16) possibly move the inclusion of Text::ParseWords out to compile
#       time
#   2009-04-06:
#     - (DONE) fix evil hax in config method
###
# History:
#
#   2009-04-16:
#     - I added a new assumption to code under, it boils down to: "This
#       module will not be nested.  All calls to AUTOLOAD will be from
#       either this module (__PACKAGE__) or it's parent ('main')."
#   2009-04-14:
#     - coded "ike" method, it needs checks to make sure that there
#       are some triggers loaded
#     - tested the new methods, they seem to be working OK
#     - coded the "load" method and two internal methods "_require" and
#       "_exists_setting".  "_reguire" is a custom built require subroutine.
#   2009-04-11:
#     - Forget about global channels for now, just make every trigger state
#       it's channels explicitly.
#     - Started yet another rewrite based on earlier brain waves and some
#       light reading through my big ole' perl black book that I forgot I
#       owned.
#   2009-04-10:
#     - brain wave #2: build my own pseudo require routine for components
#     - brain wave regarding pikabot components: Why make it complex?  Will
#       just use perl modules now.
#   2009-04-08:
#     - reworked "train" and "grab" slightly
#   2009-04-07:
#     - added Text::ParseWords.pm
#     - coded "new", "train", and "grab" methods
#     - dropped config module entirely to go full OO
#   2009-04-06:
#     - config method coded, beware of it's evil


use strict;
use warnings;

use Carp;
use Text::ParseWords; # I have to admit, quotewords() is useful.
use Pikabot::Trigger;
use Pikabot::Channel;
use Pikabot::Setting;
use Pikabot::Signal;
use Pikabot::Global;

sub AUTOLOAD {
  # Some notes on this routine:
  #   1) It's a bit of a hack.
  #   2) It's very inflexible.
  #   3) It'll do for now. :)

  # First let's make sure this is a signal routine.
  ($AUTOLOAD =~ /@{[ Pikabot::Global::SIGNAL_REGEX ]}/o and
    defined($1)) and do {

    eval '@_ = Pikabot::Signal::' . $1 . '(@_);'; # eval hax... erm evil

    # Was there an error?
    $@ and do {

      # Was it a stupid one?
      $@ =~ /undef.*sub/io and do {

        croak "Undefined subroutine &Pikabot::Signal::$1 called";
      };

      # Was it a serious one?
      croak $@;
    };

    # No errors, let's return what we found.
    return (@_);
  };

  # Dumb error.
  croak "Undefined subroutine &$AUTOLOAD called";
}

our (@ISA, @EXPORT);
my $REPORT;

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT = qw(AUTOLOAD);

  require Pikabot::Report; # import nothing
  $REPORT = Pikabot::Report->spawn or do {

    warn, croak __PACKAGE__ . ': Unable to spawn report module';
  };
}


sub spawn {
  my $class = shift;
  my %pika = @_;

  # Check the config.
  foreach my $k ( 'authors',
                  'description',
                  'name',
                  'contact',
                  'url',
                  'version') {

    exists($pika{$k}) or do {

      warn, croak $REPORT->error(1, "Config missing field: $k");
    };
  }

  my $pika = [
    { %pika },
    Pikabot::Trigger->spawn,
    Pikabot::Channel->spawn,
    Pikabot::Setting->spawn,
  ];

  return (bless $pika, $class);
}

sub load {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $REPORT->error(0);


  foreach my $component (@_) {
    my ($symbol, $filename) = _require($component);

    defined($symbol) or do {

      warn, croak $REPORT->error(4, 'Overloading not enabled');
    };


    eval {
      $symbol->BOOT;
    };

    $@ and do {

      warn, croak $REPORT->error(5, "$component boot failure: $@");
    };





sub _require ($) {
  # This is basically a slightly hacked verion of
  # perl's own require method.  I say "slightly"
  # because only what is returned is modified, the
  # rest is pretty much the same! :D

  my ($file) = @_;

  exists($INC{$file}) and do {

    $INC{$file} or do {

      warn, croak $REPORT->error(5, 'Compilation failed at %INC check');
    };

    return (undef);
  };

  foreach my $path (@INC) {
    my $fullfile = "$path/$file";

    -f $fullfile or do {

      next;
    };

    $INC{$file} = $fullfile;
    my $package = do $fullfile;

    $@ and do {

      $INC{$file} = undef;
      warn, croak $REPORT->error(5, $@);
    };
    (defined($package) and
      length($package) and
        $package) or do {

      delete($INC{$file});
      warn, croak $REPORT->error(5, "$file did not return a true value");
    };


    return ($package, $file);
  }

  warn, croak $REPORT->error(5, "Can't find $file in \@INC");
}

sub _exists_setting ($) {
  # In scalar context returns the number of matches (if
  # that number is higher than one, you have a problem
  # with your globals)... In list context returns what
  # matched.

  my ($given) = @_;

  return (grep { $type eq $_ } Pikabot::Global::SETTING_TYPE);
}

sub _check_component_symbol ($) {
  # This just makes sure the user has built his or
  # her Pikabot components correctly.

  my ($given) = @_;

  ($given =~ /@{[ Pikabot::Global::CMPNNT_REGEX ]}/o and
    defined($1)) and do {

    return ($1);
  };

  return (undef);
}

sub _symbol_to_setting ($$) {
  # Quick little hack to turn a symbol and a
  # setting into a setting string that Irssi
  # will not mind.

  my ($sym, $set) = @_;

  (defined($sym) and
    defined($set)) or do {

    return (undef);
  };


  $sym =~ s/[^A-Za-z0-9]/_/go;
  $sym =~ s/_+/_/go;

  return (lc("${sym}_${set}"));
}


__PACKAGE__;