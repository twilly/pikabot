#!/usr/bin/perl -w
package Pikabot::Setting;
# Pikabot::Setting: Storage medium for Irssi settings.
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
###
# History:
#


use strict;
use warnings;

use Carp;

my $REPORT;

BEGIN {
  require Pikabot::Report; # import nothing
  $REPORT = Pikabot::Report->spawn or do {

    warn, croak __PACKAGE__ . ': Unable to spawn report module';
  };
}


sub spawn {
  # Not much to say on this one!

  return (bless {}, shift);
}


sub register {
}

sub unregister {
  # This method unregisters an item from the $pika hash.
  # It's code has stayed pretty much the same throughout
  # this bot's development... I must have done something
  # right...

  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $REPORT->error(0);


  my ($match, $regex) = (0, @_);

  defined($regex) or do {

    warn;
    return (undef);
  };


  foreach my $i (keys(%{$pika})) { # bruteforce ;)
    $i =~ /$regex/o and do {

      delete($pika->{$i}) or do {

        warn;
        return (undef);
      };

      $match++;
    };
  }


  return ($match);
}

sub keys {
  # Pretty self-explanitory.

  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, confess $REPORT->error(0);


  return (keys(%{$pika}));
}


__PACKAGE__;