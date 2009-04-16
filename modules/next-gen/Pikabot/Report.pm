#!/usr/bin/perl -w
package Pikabot::Report;
# Pikabot::Report: Container of all the error strings and report formats.
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
#     - possibly remove Exporter completely, probably don't need it
#   2009-04-07:
#     - Use "caller()" somehow for the ERRSTR/ERROR function?
#   2009-04-06:
#     - (DROP) boil the list of messages down some
#     - (DONE) fix exporter bug
###
# History:
#
#   2009-04-16:
#     - fixed the busted Exporter usage
#   2009-04-14:
#     - included the first call to caller!! :D (in spawn)
#   2009-04-11:
#     - switch to OO for some reason
#   2009-04-07:
#     - recoded "ERROR"
#     - dropped config module entirely to go full OO
#   2009-04-06:
#     - moved "ERROR" to this module
#     - finished initial coding and testing of functionality


use strict;
use warnings;

our (@ISA, @EXPORT_OK);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(_error_string);
}


# my stuff
sub _error_string ($) {
  # This method will decimate IO... But since it's only called
  # to die I don't see a problem. :P  Maybe it would be smarter
  # to make an array of refs to subs outside the __DATA__ token
  # and use SelfLoader?  Or simply pull an acme and parse __DATA__
  # where it contains one error message per line, just set (or
  # run through $. [line number]) to the one we want, and read it.
  # But for now, I'm lazy and this will do.
  return [
    'Invalid object', #0
    'Unable to spawn', #1
    'Unknown author', #2
    'Unable to unregister', #3
    'Unable to register', #4
    'Unable to load component', #5
    'You can\'t init the bot twice', #6
    'Error fetching signal call', #7

  ]->[int(abs(shift))]; # I don't even trust myself.
}

# methods
sub spawn {
  my $class = shift;


  my ($package) = @_;

  defined($package) or do {

    $package = caller;
  };


  return (bless \$package, $class);
}

sub error {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or
    warn, return (__PACKAGE__ . ': Invalid object calling ERROR method');


  my ($error, $message) = @_;

  length(_error_string($error)) or do {

    warn, return (__PACKAGE__ . ': Specified error string does not exist');
  };
  (defined($message) and
    length($message)) or do {

    $message = '';
  };
  length($message) and do {

    $message = ": $message";
  };


  return ("${$pika}: " . _error_string($error) . $message);
}


__PACKAGE__;