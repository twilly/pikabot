#!/usr/bin/perl -w
package Pikabot;
# Pikabot: The cutest bot you've ever seen.
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
#   2009-04-06:
#     - fix evil hax in config method
###
# History:
#
#   2009-04-06:
#     - config method coded, beware of it's evil


use strict;
use warnings;

use Carp;

use Pikabot::Config;
use Pikabot::Reports qw(ERROR);
use Pikabot::Trigger;


sub config (\%) {
  my $class = shift;

  my ($config) = @_;

  foreach my $c (keys(%{$config})) {
    eval "\$Pikabot::Config::$c = '" . $config->{$c} . '\';'; # evil hax, but whatever
    $@ and
      warn, croak ERROR(14);
  }

  $Pikabot::Config::CONFIGED = 1;
}

sub spawn {
  my $class = shift;

  $Pikabot::Config::CONFIGED or
    warn, croak ERROR(15);
}


'Pikachu!';