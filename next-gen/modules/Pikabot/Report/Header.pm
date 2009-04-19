#!/usr/bin/perl -w
package Pikabot::Report::Header;
# Pikabot::Report::Section: Holds the header for error and warning messages.
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

our(@ISA, @EXPORT_OK);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(h_string);
}

sub h_string ($) {
  my ($i) = @_;

  defined($i) or do {

    confess __PACKAGE__ . ': Message to be retrieved was not defined';
  };


  my $h = int(abs($i)); # safety! :D


  while (<DATA>) {
    $. == $h and do {

      # This allows for comments at the end of a line in __DATA__.  If
      # you want a "#" in your line, prefix it with "\"...
      s/\s*(?<!\\)#.*//o; # drop comments
      s/\\#/#/go;

      length or do {

        next;
      };

      chomp;

      return ($_);
    };
  }

  confess __PACKAGE__ . ": Could not find message at given index: $h";
}

__PACKAGE__;

__DATA__
Unable to spawn bot # 1
Method "load" called too early # 2
Unable to load component # 3