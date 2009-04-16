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
#   2009-04-16:
#     - Change SIGNAL_REGEX to be less strict.
#     - Could possibly add Exporter to some kind of hack that
#       reads my (Pikabot::Globals) symbol table and builds a @EXPORT
#       array from that.
###
# History:
#
#   2009-04-16:
#     - Switched to SelfLoader.  Since these subs are really small, their
#       on-the-fly compile time will be next to nothing.
#     - added some globals

use strict;
use warnings;

use SelfLoader;


__PACKAGE__;


__DATA__

sub MODULE_REGEX () { '\.(?i:pm)$' }
sub BOT_REVISION () { 'r91' }
sub SETTING_TYPE () { qw(str int bool time level size) }
sub SETTING_BASE () { 'Irssi::settings_add_' }
sub CMPNNT_REGEX () { '^Pikabot\:\:Component\:\:(\S+)$' }
sub SIGNAL_REGEX () { '^main\:\:signal_(\S+)$' }