#!/usr/bin/perl -w

# pika_driver: Implementation of the cutest bot you've ever seen.
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
#     - coded initial crap

use strict;
use warnings;

use Pikabot;

my %config = (
  'BOT_NAME' => 'test_bot',
  'BOT_VERSION' => '0',
  'COMPONENT_DIRECTORY' => '.',
  'GLOBAL_CHANNELS' => [ '(?i:test)' ],
);

Pikabot->config(\%config);

my $bot = Pikabot->spawn;