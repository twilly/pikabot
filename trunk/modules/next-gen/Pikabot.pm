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
#   2009-04-14:
#     - Add checks to "ike" method.
#   2009-04-11:
#     - Replace spawn checks/config with call to $main::VERSION and
#       %main::IRSSI?  Problems might occur if this module is nested...
#   2009-04-07:
#     - Simplify configuration a little (E.G: For global channels, allow
#       scalar values to be pushed onto the stack.)
#     - (DROP) possibly move the inclusion of Text::ParseWords out to compile
#       time
#   2009-04-06:
#     - (DONE) fix evil hax in config method
###
# History:
#
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

# Random globals:
sub MODULE_REGEX () { '\.(?i:pm)$' }
sub BOT_REVISION () { 'r91' }
sub SETTING_TYPE () { qw(str int bool time level size) }
sub SETTING_BASE () { 'Irssi::settings_add_' }

use Carp;
use Text::ParseWords; # I have to admit, quotewords() is useful.

use Pikabot::Trigger;
use Pikabot::Reports;

my $report;

BEGIN {
  $report = Pikabot::Reports->spawn(__PACKAGE__) or do {

    die __PACKAGE__ . ': Error spawning reporting object';
  };

#  require Irssi; # don't import anything
}

sub spawn {
  my $class = shift;
  my ($name, $version, $authors) = @_;

  (defined($name) and
    not ref($name) and
      length($name)) or do {

    warn, croak $report->error(1, 'Missing valid bot name');
  };
  (ref($authors) eq 'HASH' and
    keys(%{$authors}) > 0) or do {

    warn, croak $report->error(1, 'Missing valid authors hash');
  };
  (defined($version) and
    not ref($version) and
      length($version)) or do {

    warn, croak $report->error(1, 'Missing valid version string');
  };


  my $pika = [
    $name,
    $version,
    $authors,
    Pikabot::Trigger->spawn,
    # more stuff here
    0,
  ];


  return (bless $pika, $class);
}

sub load {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $report->error(0);


  foreach my $component (@_) {
    my $symbol = _require($component);

    defined($symbol) or do {

      warn, croak $report->error(4, 'Overloading not enabled');
    };


    eval {
      $symbol->BOOT;
    };

    $@ and do {

      warn, croak $report->error(4, "Unable to BOOT $component: $@");
    };


    my %setting = $symbol->SETTINGS;
#    my @signal = $symbol->SIGNALS; # reserved for future use
    my %trigger = $symbol->TRIGGERS;
    my $name = lc($symbol);
    my $heyo = lc(ref($pika));

    $name =~ s/(?:\:\:|\s+)/_/go;
    $name =~ s/component//igo;
    $name =~ s/_+/_/go;
    $heyo =~ s/(?:\:\:|\s+)/_/go;
    $heyo =~ s/_+/_/go;


    # Parse the settings.
    foreach my $i (keys(%setting)) {
      _exists_setting($setting{$i}->[0]) or do {

        warn, croak $report->error(5, 'Unknown setting type "' . $setting{$i}->[0] . "\" for $i");
      };

      my $key = "${name}_${i}";
      my $add = SETTING_BASE . $setting{$i}->[0] . "($heyo, $key, " . $setting{$i}->[1] . ');';

      eval $add;

      $@ and do {

        warn, croak $report->error(5, "Unable to add setting $key: $@");
      };


      $setting{$i} = $key;
    }

    # Load the trigger!
    foreach my $t (keys(%trigger)) {
      $pika->[3]->register($t => [$trigger{$t}, [ $symbol->CHANNELS ], [ keys(%setting) ]]) or do {

        warn, croak $report->error(5);
      };
    }
  }

  return (scalar $pika->[3]->triggers);
}

sub name {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $report->error(0);


  return ($pika->[0]);
}

sub version {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $report->error(0);


  return ($pika->[1]);
}

sub authors {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $report->error(0);


  my ($author) = @_;

  not defined($author) and do {

    return (keys(%{$pika->[2]}));
  };
  exists($pika->[2]->{$author}) and do {

    return ($pika->[2]->{$author});
  };


  warn, croak $report->error(2);
}

sub ike {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $report->error(0);


  $pika->[-1] and do {

    warn, croak $report->error(6);
  };

  $pika->[-1] = not $pika->[-1];
}


# My stuff~!
sub _require ($) {
  my ($file) = @_;

  exists($INC{$file}) and do {

    $INC{$file} or do {

      warn, croak $report->error(5, 'Compilation failed at %INC check');
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
      warn, croak $report->error(5, "$@");
    };
    (defined($package) and
      length($package)) or do {

      delete($INC{$file});
      warn, croak $report->error(5, "$file did not return a true value");
    };


    return ($package);
  }

  warn, croak $report->error(5, "Can't find $file in \@INC");
}

sub _exists_setting ($) {
  my ($given) = @_;

  foreach my $type (SETTING_TYPE) {
    $given eq $type and do {

      return (1);
    };
  }

  return (0);
}


__PACKAGE__;