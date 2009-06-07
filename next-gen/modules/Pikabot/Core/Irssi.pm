#!/usr/bin/perl -w
package Pikabot::Core::Irssi;
# Pikabot::Core::Irssi: The cutest bot-core you've ever seen.
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
# History
#
#   2009-04-22:
#     - Coded some crap.  Basically this module will be the "heart" of
#       Pikabot, it will abstract some core functionality for easier
#       client porting! :D  As you may well of noticed, this one is
#       called "Pikabot::Core::Irssi" meaning that it's for Irssi. :)


use strict;
use warnings;

use Irssi;
use Pikabot::Global;
use Pikabot::Core::Irssi::Signal;

our ($SIG);

BEGIN {
  $SIG = __PACKAGE__ . '::Signal';
}


# External subs go here.  If you want an internal sub to be compiled earlier,
# simply prefix it with a "_" as per Perl convention and the routine in the
# "BEGIN" block will not export it.


# Settings stuff:

sub setting_get {
  # Should return undef on error.
}

sub setting_add {
  # Should return undef on error.
}

sub setting_set {
  # Should return undef on error.
}


# Channel functionality stuff:

sub channel_join {
  # Should return undef on error.
}

sub channel_part {
  # Should return undef on error.
}

sub channel_kick {
  # Should return undef on error.
}

sub channel_ban {
  # Should return undef on error.
}

sub channel_topic {
  # Should return topic if no params, set otherwise and
  # return undef on errors.
}


# Command stuff:

sub command_add {
  # Undef on errors.
}

sub command_get {
  # Gets a list of commands, I guess.  Return undef on errors.
}

sub command_run {
  # BAAAAAAAAAANNNZAAIIIII.  Return undef on errors.
}


# Network stuff:

sub network_connect {
  # I don't think I'll bother with "server" stuff, just network.

  # Should return undef on error.
}

sub network_disconnect {
  # Should return blah blah blah...
}


# Other good stuff:

sub external_message {
  # Not sure what to do here yet, but return undef on error still applies.
}

sub external_action {
  # Ditto...
}

sub internal_message {
  # For error reporting, whatever.  Return undef on error.
}



# Export block.  This is where the magic happens.
our(@ISA, @EXPORT);

BEGIN {
  use symtest;

  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT = grep {
    !/^_/o and # exclude "internal" methods
      symbolize(__PACKAGE__, $_, 'CODE')
  } keys(%{symbolize(__PACKAGE__)}) or do {

    die; # die if there's nothing in the table or symbol_ref returns undef
  };
}



# Internal subs go here.  They can follow whatever convention you want! :D
# Since they come after the symbol table is parsed, it really doesn't matter.

# subs


# End~.
__PACKAGE__;