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
#       scalar values to be pushed onto the
#       stack.
#     - (DROP) possibly move the inclusion of Text::ParseWords out to compile
#       time
#   2009-04-06:
#     - (DONE) fix evil hax in config method
###
# History:
#
#   2009-04-07:
#     - coded "configure" method
#     - coded "new" method
#     - dropped config module entirely to go full OO
#   2009-04-06:
#     - config method coded, beware of it's evil


use strict;
use warnings;

sub REVISION () { 'r88' }

use Carp;

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

sub nouveau {
  my $class = shift;


  my (
    $BOT,

    # Enable or disable the use of Irssi's settings.
    $USE_IRSSI_SETTINGS,

    # If the use of Irssi's settings is enabled, these will be what
    # is looked for.  They should be prefixed by "${BOT_NAME}_" for
    # safety.
    $IRSSI_SETTINGS_GLOBAL_CHANNELS,
    $IRSSI_SETTINGS_COMPONENT_DIRECTORY,

    # These must be set by the driver.
    $BOT_NAME,
    $BOT_VERSION,
    $BOT_AUTHORS,

    # These can be set by the driver, or Irssi's settings.
    $BOT_COMPONENT_DIRECTORY,
    $BOT_COMPONENT_EXT_REGEX,
    $BOT_GLOBAL_CHANNELS,
  ) = (
    undef,
    0,
    undef, undef,
    undef, undef, {},
    undef, undef, [],
  );


  $BOT = [
    # Settings & configuration.
    {
      USE_IRSSI_SETTINGS => \$USE_IRSSI_SETTINGS,
      IRSSI_SETTINGS_GLOBAL_CHANNELS => \$IRSSI_SETTINGS_GLOBAL_CHANNELS,
      IRSSI_SETTINGS_COMPONENT_DIRECTORY => \$IRSSI_SETTINGS_COMPONENT_DIRECTORY,
      BOT_NAME => \$BOT_NAME,
      BOT_VERSION => \$BOT_NAME,
      BOT_AUTHORS => \$BOT_AUTHORS,
      BOT_COMPONENT_DIRECTORY => \$BOT_COMPONENT_DIRECTORY,
      BOT_COMPONENT_EXT_REGEX => \$BOT_COMPONENT_EXT_REGEX,
      BOT_GLOBAL_CHANNELS => \$BOT_GLOBAL_CHANNELS,
    },
  ];


  return (bless $BOT, $class);
}

sub configure {
  my $pikachu = shift;

  ref($pikachu) or
    warn, croak ERROR(18, '', 'configure');


  my ($options) = @_;

  if (defined($options)) {
    ref($options) eq 'HASH' or
      warn, croak ERROR(19);
  } else {
    return (keys(%{$pikachu->[0]}));
  }


  foreach my $o (keys(%{$options})) {
    exists($pikachu->[0]->{$o}) or
      warn, croak ERROR(20, '', $o);

    $pikachu->[0]->{$o} = $options->{$o};
  }
}


'Pikachu!';