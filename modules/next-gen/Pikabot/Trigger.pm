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
#   2009-04-07:
#     - (DONE 2009-04-08) add data checks when registering a trigger
###
# History:
#
#   2009-04-08:
#     - developed a new (better) error throwing method
#   2009-04-07:
#     - changed the layout of triggers data structure again >_>
#   2009-04-06:
#     - changed around the trigger's data structure, now it holds some meta as
#       well as the trigger code
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
sub register ($\@) {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);


  # Layout should hold:
  #   0) full file name of components (scalar)
  #   1) trigger (code ref)
  my ($trigger, $layout) = @_;


  # Check the trigger:
  (not ref($trigger) and
    ref($layout) eq 'ARRAY' and
      @{$layout} == 2
        ref($layout->[1]) eq 'CODE' and
          -e $layout->[0]) or do {

    carp ERROR(1, SECTION_NAME);
    return (undef);
  };

  exists($self->{$trigger}) and do {

    carp ERROR(0, SECTION_NAME);
    return (undef);
  };


  # Register the trigger:
  $self->{$trigger} = $layout;


  # Return a true value:
  return (1);
}


# unregister method, removes triggers that match a given regex from the hash
sub unregister ($) {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);


  my ($trigger) = @_;
  my $match = 0;

  defined($trigger) or do {
    carp ERROR(4);
    return (undef);
  };


  foreach my $t (keys(%{$self})) {
    $t =~ /$trigger/o and do {
      delete($self->{$t}) or do {
        carp ERROR(5);
        return (undef);
      };

      $match++;
    };
  }


  $match > 0 or
    carp ERROR(6);

  return ($match);
}


# wraps keys()
sub triggers () {
  my $self = shift;

  ref($self) or
    warn, confess ERROR(3, SECTION_NAME);


  return (keys(%{$self}));
}


'Pikachu!';