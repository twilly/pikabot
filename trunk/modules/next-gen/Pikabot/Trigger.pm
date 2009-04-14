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
#   2009-04-14:
#     - Change the way triggers are registered to be less dumb.
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

use Pikabot::Reports;
my $report = Pikabot::Reports->spawn(__PACKAGE__);


# not much to screw up here >_>
sub spawn {
  return (bless {}, shift);
}


# Register
#   Registers a trigger in the hash, does some checks
#   on the data as well.
sub register {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or # no need for inheritance
    warn, confess $report->error(0);


  # Layout should hold:
  #   0) full file name of components (scalar)
  #   1) trigger (code ref)
  #   2) the triggers channels (array ref)
  my ($trigger, $layout) = @_;

  # Check trigger regex.
  not ref($trigger) or do {

    warn, carp $report->error(4, 'Bad trigger name');
    return (undef);
  };
  # Check trigger layout and the number of items.
  (ref($layout) eq 'ARRAY' and
    @{$layout} == 3) or do {

    warn, carp $report->error(4, 'Invalid layout');
    return (undef);
  };
  # Check the trigger code.
  ref($layout->[0]) eq 'CODE' or do {

    warn, carp $report->error(4, 'Trigger must return code reference');
    return (undef);
  };
  # Make sure there's atleast one channel.
  @{$layout->[1]} > 0 or do {

    warn, carp $report->error(4, 'No channels were specified');
    return (undef);
  };
  # Check that this trigger wasn't already registered.
  exists($pika->{$trigger}) and do {

    warn, carp $report->error(4, 'Overloading not supported');
    return (undef);
  };


  # Register the trigger:
  $pika->{$trigger} = $layout;

  # Return a true value:
  return (1);
}


# unregister method, removes triggers that match a given regex from the hash
sub unregister {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or # no need for inheritance
    warn, confess $report->error(0);


  my ($trigger) = @_;
  my $match = 0;

  defined($trigger) or do {

    warn, carp $report->error(3, 'Search regex was undefined');
    return (undef);
  };


  foreach my $t (keys(%{$pika})) {
    $t =~ /$trigger/o and do {

      delete($pika->{$t}) or do {

        warn, carp $report->error(3, "Deletion of key '$t' failed");
        return (undef);
      };

      $match++;
    };
  }


  $match > 0 or do {

    warn, carp $report->error(3, 'No matches were found');
    return (0);
  };

  return ($match);
}


# wraps keys()
sub triggers {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or # no need for inheritance
    warn, confess $report->error(0);


  return (keys(%{$pika}));
}


__PACKAGE__;