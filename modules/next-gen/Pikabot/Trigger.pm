#!/usr/bin/perl -w
package Pikabot::Trigger;
# Pikabot::Trigger: Module for dealing with triggers.
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
#   2009-04-06:
#     - changed around the trigger's data structure, now it holds some meta as well as the trigger code
#     - updated error throwing method
#     - added some constants to hold information for error throwing
#     - finished initial coding and testing of functionality


use strict;
use warnings;

use Carp;

use Pikabot::Reports qw(ERROR);

# inlined constants
sub SECTION_NAME () { 'Trigger' }


# not much to screw up here >_>
sub new {
  return (bless {}, shift);
}

# register method, stores a trigger in the hash
sub register ($\%) {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);

  my ($trigger, $layout) = @_;
  $self->{$trigger} = $layout;

  return (1);
}

# unregister method, removes triggers that match a given regex from the hash
sub unregister ($) {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);

  my ($trigger) = @_;
  my $match = 0;

  defined($trigger) or
    warn, croak ERROR(4, SECTION_NAME);

  foreach my $t (keys(%{$self})) {
    $t =~ /$trigger/o and do {
      delete($self->{$t}) or
        warn, croak ERROR(5, SECTION_NAME, "'$t'");
      $match++;
    };
  }

  $match > 0 or
    warn, croak ERROR(6, SECTION_NAME);

  return ($match);
}

# wraps keys()
sub triggers () {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);

  return (keys(%{$self}));
}

sub channels (;$) {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);

  my ($trigger) = @_;

  defined($trigger) and do {
    exists($self->{$trigger}) or
      return (undef);
    return ($self->{$trigger}->[1]);
  };

  return (
    map {
      $_ => $self->{$_}->[1]
    } keys(%{$self})
  );
}


'Pikachu!';