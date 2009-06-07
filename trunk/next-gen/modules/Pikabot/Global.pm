#!/usr/bin/perl -w
package Pikabot::Global;
# Pikabot::Global: Pikabot's global stuff.
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
#     - (DROP 2009-04-22) Could possibly add Exporter to some kind of
#       hack that reads my (Pikabot::Globals) symbol table and builds a
#       @EXPORT array from that.  It could be done using the END construct
#       instead of the BEGIN construct, that way the subs could all be folded
#       down by the optimizer and made into constants.
#   2009-04-16:
#     - (DROP 2009-04-22) Change SIGNAL_REGEX to be less strict.
#     - (UPDATE 2009-04-19) Could possibly add Exporter to some kind of
#       hack that reads my (Pikabot::Globals) symbol table and builds a
#       @EXPORT array from that.
###
# History:
#
#   2009-04-22:
#     - Dropped a few, added a few.
#   2009-04-19:
#     - Dropped "REPORT_LEVEL", it is no longer used.
#   2009-04-18:
#     - Dropped "BOT_REVISION", "CONFIG_REGEX" and "MODULE_REGEX" as they
#       are all now handled by the driver.
#     - List was getting a bit big, so I changed the layout to be more
#       intuitive.
#   2009-04-16:
#     - Switched to SelfLoader.  Since these subs are really small, their
#       on-the-fly compile time will be next to nothing.
#     - added some globals


use strict;
use warnings;

use SelfLoader;


__PACKAGE__;


__DATA__

sub SETTING_TYPE ()
  { qw(str int bool time level size) }

sub CMPNNT_REGEX ()
  { 'Pikabot\:\:Component\:\:\S+$' }

sub SIGNAL_REGEX ()
  { '^(?:main|Pikabot)\:\:signal_(\S+)$' }

sub BAD_CORE_GEX ()
  { 'Can.t locate (.+?) in .INC' }

sub CONFIG_FIELD ()
  { qw(name url core description authors contact version) }

sub LAYOUT_FIELD ()
  { 'bot' }

sub PERLINT_NAME ()
  { 'Perl Commandline Interpreter' }

sub TRIGGER_CHAR ()
  { '!' }

sub METHOD_CHART ()
  { qw(BOOT) }