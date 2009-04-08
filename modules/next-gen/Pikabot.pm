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

sub REVISION () { 'r88' }

use Carp;
use Text::ParseWords; # I have to admit, quotewords() is useful.

use Pikabot::Reports qw(ERROR);
use Pikabot::Trigger;

#BEGIN {
#  eval {
#    require Irssi;
#  };
#
#  $@ and
#    warn, croak ERROR(17);
#}

sub new {
  my $class = shift;


  my (
    $BOT,

    # Enable or disable the use of Irssi's settings.
    $USE_IRSSI_SETTINGS,

    # These must be set by the driver.
    $BOT_NAME,
    $BOT_VERSION,
    $BOT_AUTHORS,

    # These can be set by the driver, or Irssi's settings.
    $BOT_COMPONENT_DIRECTORY,
    $BOT_COMPONENT_EXT_REGEX,
    $BOT_GLOBAL_CHANNELS,

    # Reserved for future stuff.
  ) = (
    undef,
    0,
    undef, undef, {},
    undef, undef, [],

  );


  $BOT = [
    # Settings & configuration.
    {
      USE_IRSSI_SETTINGS => \$USE_IRSSI_SETTINGS,
      BOT_NAME => \$BOT_NAME,
      BOT_VERSION => \$BOT_NAME,
      BOT_AUTHORS => \$BOT_AUTHORS,
      BOT_COMPONENT_DIRECTORY => \$BOT_COMPONENT_DIRECTORY,
      BOT_COMPONENT_EXT_REGEX => \$BOT_COMPONENT_EXT_REGEX,
      BOT_GLOBAL_CHANNELS => \$BOT_GLOBAL_CHANNELS,
    },

    # Reserved for future stuff.
  ];


  return (bless $BOT, $class);
}

sub train {
  my $pikachu = shift;

  ref($pikachu) or
    warn, confess ERROR(3);


  my ($options) = @_;

  defined($options) or
    warn, croak ERROR(19)
  ref($options) eq 'HASH' or
    warn, croak ERROR(19);


  foreach my $o (keys(%{$options})) {
    exists($pikachu->[0]->{$o}) or
      warn, croak ERROR(20, '', $o);

    $pikachu->[0]->{$o} = $options->{$o};
  }
}

sub grab {
  my $pikachu = shift;

  ref($pikachu) or
    warn, confess ERROR(3);


  my ($option) = @_;

  defined($option) or
    return (keys(%{$self->[0]}));
  ref($option) and
    warn, croak ERROR(22)
  exists($pikachu->[0]->{$option}) or
    warn, croak ERROR(22);


  return ($pikachu->[0]->{$option});
}

sub spawn {
  my $pikachu = shift;

  ref($pikachu) or
    warn, confess ERROR(3);


  # Check required options:
  defined($pikachu->[0]->{'BOT_NAME'}) or
    warn, croak ERROR(23);
  defined($pikachu->[0]->{'BOT_VERSION'}) or
    warn, croak ERROR(23);
  keys(%{$pikachu->[0]->{'BOT_AUTHORS'}}) > 0 or
    warn, croak ERROR(23);

  # If we're getting the other options from Irssi, let's do it:
  $pikachu->[0]->{'USE_IRSSI_SETTINGS'} and do {
    my $gc = Irssi::settings_get_str($pikachu->[0]->{'BOT_NAME'} . '_global_channels')

    length($gc) or
      warn, croak ERROR(24);

    $pikachu->[0]->{'BOT_GLOBAL_CHANNELS'} = [ quotewords(',', 0, $gc) ];


    my $cd = Irssi::settings_get_str($pikachu->[0]->{'BOT_NAME'} . '_component_directory');

    length($cd) or
      warn, croak ERROR(24);

    $pikachu->[0]->{'BOT_COMPONENT_DIRECTORY'} = $cd;


    my $cr = Irssi::settings_get_str($pikachu->[0]->{'BOT_NAME'} . '_component_ext_regex');

    defined($cr) or
      warn, croak ERROR(24); # Irssi seem to always return a defined value, and techincally a regex of '' is accetable..... so I dunno about this check

    $pikachu->[0]->{'BOT_COMPONENT_EXT_REGEX'} = $cr;
  };


  # Time to check the other options:
  @{$pikachu->[0]->{'BOT_GLOBAL_CHANNELS'}} > 0 or
    warn, croak ERROR(8);
  -d $pikachu->[0]->{'BOT_COMPONENT_DIRECTORY'} or
    warn, croak ERROR(7);
  defined($pikachu->[0]->{'BOT_COMPONENT_EXT_REGEX'}) or
    warn, croak ERROR(25);


  # Find the components:
  opendir(CMP, $pikachu->[0]->{'BOT_COMPONENT_DIRECTORY'}) or
    warn, croak ERROR(9);

  my @components = grep {
    not -d and
      /@{[ $pikachu->[0]->{'BOT_COMPONENT_EXT_REGEX'} ]}/o
  } readdir(CMP);

  close(CMP) or
    warn, croak ERROR(10);


  # Load the components:
  $pikachu->[1] = Pikabot::Trigger->new; # holds the code
  $pikachu->[2] = Pikabot::Channel->new; # holds channel list
  $pikachu->[3] = Pikabot::Signal->new; # holds signal list

  foreach my $c (@components) {
    my $f = $pikachu->[0]->{'BOT_COMPONENT_DIRECTORY'} . "/$c";
    my ($t, $d) = do $f;

    (ref($d) eq 'ARRAY' and
      @{$d} == 3 and
        not ref($t)) or
          warn, croak ERROR(27);


    for (my $i = @{$d}; $i--; ) {
      $pikachu->[$i]->register($t, $d->[$i]) or
        warn, croak ERROR(26);
    }
  }


  # Return the number of components we loaded, incase the user is being verbose:
  return (scalar $pikachu->[1]->triggers);
}


'Pikachu!';