#!/usr/bin/perl -w
package Pikabot::Reports;
# Pikabot::Reports: Container of all the error strings and report formats.
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
#     - Use "caller()" somehow for the ERRSTR/ERROR function?
#   2009-04-06:
#     - boil the list of messages down some
#     - (DONE) fix exporter bug
###
# History:
#
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
  @EXPORT_OK = qw(ERRSTR REPSTR ERROR);
}

# inlined constants
sub SECTION_NAME () { 'Reports' }


sub ERRSTR ($) {
  return [
    'Unable to overload existing trigger:  Overloading not supported, please unregister first', #0
    'Unable to register trigger:  Invalid trigger', #1
    'Unable to register triggers:  No triggers given', #2
    'Reference error', #3 - this one is bad
    'Unable to unregister trigger:  No regex given', #4
    'Unable to unregister trigger:  Failure to delete', #5
    'Unable to unregister trigger:  No matches found', #6
    'Unable to spawn:  Component directory does not exist', #7
    'Unable to spawn:  Global channels are currently required', #8
    'Unable to spawn:  Unable to access component directory', #9
    'Unable to spawn:  Unable to close component directory', #10
    'Unable to spawn:  No compatible components found', #11
    'Unable to spawn:  Error compiling components', #12
    'Unable to edit config options:  Option does not exists', #13
    'Sorry bub, that didn\'t work', #14
    'Can\'t spawn a Pikachu that isn\'t setup :/', #15
    'Unable to spawn:  Irssi settings strings were not configured', #16
    'Unable to initialize:  You don\'t seem to be running Irssi', #17
    'Called too early', #18
    'Unable to configure:  Options must be hash reference', #19
    'Unable to configure:  Unknown option', #20
    'Invalid use', #21
    'Unable to get option:  Unknown option', #22
    'Unable to spawn:  Missing required option', #23
    'Unable to get option:  Option does not exist; or, is not defined', #24
    'Unable to spawn:  Invalid or undefined regex supplied', #25
    'Unable to register trigger:  Please check your components code', #26
    'Unable to load component:  Invalid structure', #27

  ]->[int(abs(shift))]; # I don't even trust myself.
}

sub REPSTR ($) {
  # reserved for future use
}

sub ERROR ($;$$) {
  my ($level, $section, $message) = @_;

  defined(ERRSTR($level)) or
    return (warn 'Pikabot::Reports: You gotta be real dumb to mess this up');

  defined($section) or
    $section = '';
  defined($message) or
    $message = '';
  length($section) and
    $section = "::$section";
  length($message) and
    $message = ": $message";

  return (sprintf('Pikabot%s: %s%s', $section, ERRSTR($level), $message));
}


'Pikachu!';