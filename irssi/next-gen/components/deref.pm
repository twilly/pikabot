#!/usr/bin/perl -w
package Pikabot::Component::Deref;
# deref: Dereferencing module for Pikabot.  This is an example of Pikabot's
#        component's coding standard, I guess.
#
# Copyright (C) 2009  Justin Lee  < kool.name at gmail.com >
# Some Code Copyright (C) 2006  Tristan Willy  < tristan.willy at gmail.com >
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
#   2009-04-14:
#     - Move "$type" check (for send_message) out to driver or Pikabot?
###
# History:
#
#   2009-04-16:
#     - Removed setting, signal, and channel boot methods... Now pc will be
#       happy, right?   I think they'll get moved into a configuration file
#       or be completely managed by the driver script... Who knows.
#   2009-04-14:
#     - base coding done


use strict;
use warnings;

use LWP;
