#!/usr/bin/perl -w
package Pikabot::Report;
# Pikabot::Report: Builds error strings and warning messages.
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
#   2009-04-19:
#     - Fix caller being called twice in "error" method...
#   2009-04-18:
#     - (DROP 2009-04-19) develop better method for returning error string
#   2009-04-16:
#     - (DROP 2009-04-18) possibly remove Exporter completely, probably don't need it
#   2009-04-07:
#     - (DONE 2009-04-18) Use "caller()" somehow for the ERRSTR/ERROR function?
#   2009-04-06:
#     - (DROP) boil the list of messages down some
#     - (DONE) fix exporter bug
###
# History:
#
#   2009-04-19:
#     - Imported Pikabot::Report::Section and Pikabot::Report::Header and
#       made the required changes to this module.
#     - Split the messages out to their own files! :D
#   2009-04-18:
#     - further implmented "caller" and moved away from
#       object oriented
#     - fixed bug in the "error" method
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

use Carp;

use Pikabot::Global;
use Pikabot::Report::Section qw(s_string);
use Pikabot::Report::Header qw(h_string);

our (@ISA, @EXPORT_OK);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT_OK = qw(error);
}



# Internal methods and the like.

sub _rename_e ($) {
  my ($file) = @_;

  $file eq '-e' and do {

    -f $file and do {

      return ($file); # allows for files named -e
    };

    return (Pikabot::Global->PERLINT_NAME);
  };

  return (undef); # uh oh
}


# External methods and the like.

sub error ($$;$) {
  my ($h, $s, $m) = @_;
  my ($header, $section) = (h_string($h), s_string($s));

  defined($m) or do {

    $m = '';
  };
  length($m) and do {

    $m = ": $m";
  };


  if (defined(caller(1))) {
    my ($p, $f, $l, $s, $a, $w, $e, $r, $h, $b, $i) = caller(1);

    my $pkg = $p . '->' . $s;
    my $file = _rename_e($f);

    defined($file) or do {

      confess __PACKAGE__ . ': Caller gave a bad file descriptor';
    };

    return ("${pkg}: ${header}: ${section}${m} at ${file} line ${l}... ");
  } else {
    my ($p, $f, $l) = caller;

    my $pkg = _trim_package($p);
    my $file = _rename_e($f);

    defined($file) or do {

      confess __PACKAGE__ . ': Caller gave a bad file descriptor';
    };


    return ("${pkg}: ${header}: ${section}${m} at ${file} line ${l}... ");
  }
}


__PACKAGE__;