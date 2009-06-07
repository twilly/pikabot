#!/usr/bin/perl -w
package Pikabot::Report::Section;
# Pikabot::Report::Section: Holds sectional error and warning messages.
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
#   2009-04-19:
#     - Coded initial crap.


use strict;
use warnings;

use Carp;

our (@ISA, @EXPORT_OK);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(s_string);
}

sub s_string ($) {
  my ($i) = @_;

  defined($i) or do {

    confess __PACKAGE__ . ': Message to be retrieved was not defined';
  };


  my $s = int(abs($i)); # safety! :D


  while (<DATA>) {
    $. == $s and do {

      chomp;

      # This allows for comments at the end of a line in __DATA__.  If
      # you want a "#" in your line, prefix it with "\"...
      s/\s*(?<!\\)#.*//o; # drop comments
      s/\\#/#/go;

      length or do {

        next;
      };

      return ($_);
    };
  }

  confess __PACKAGE__ . ": Could not find message at given index: $s";
}

__PACKAGE__;


__DATA__
Could not find given symbol # 1
Was not given a useful reference # 2
Given symbol does not exist # 3
Given symbol does not contain a hash # 4
Required setup key missing or undefined # 5
Invalid autoconfig directory given # 6
Given autoconfig path MUST be in @INC # 7
The bot must be spawned first # 8
Malformed component info hash # 9
Attempted overload # 10
Component returned an invalid package name # 11
Storage of config file failed # 12
Compilation failed # 13
Specified file already exists # 14
lock_store encountered an error # 15
Unable to autoconfigure # 16
Bad file descriptor # 17
Bot already frozen # 18
Specified file does not exist # 19
lock_retrieve encountered an error # 20
Class mismatch # 21
Could not locate configuration file # 22
Pikabot seems to have been improperly stored # 23