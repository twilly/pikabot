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
#   2009-04-07:
#     - scratch that, we're back to the start
#   2009-04-06:
#     - coded initial crap

use strict;
use warnings;

BEGIN {
	sub MODULES_LIB			() { '../modules/next-gen' }
	sub CMPNNTS_LIB			() { './components' }
	sub BOT_NAME				() { 'Cuteb0t' }
	sub BOT_DESC				() { 'The cutest b0t you\'ve ever seen.' }
	sub BOT_AUTH				() { 'Justin Lee, Tristan Willy, Andreas Högström' }
	sub BOT_CONT				() { 'kool.name, tristan.willy, superjojo at gmail.com' }
	sub BOT_VERS				() { 0.01 }
	sub BOT_HTTP				() { 'http://pikabot.googlecode.com/' }
}

use lib MODULES_LIB;
use lib CMPNNTS_LIB;

use Pikabot;
use Irssi;

our(%IRSSI, $VERSION, %BOT);

$VERSION = BOT_VERS;

%IRSSI = (
	'authors'			=> BOT_AUTH,
	'contact'			=> BOT_CONT,
	'name'				=> BOT_NAME,
	'description'	=> BOT_DESC,
	'url'					=> BOT_HTTP,
);

%BOT = (
	%IRSSI,
	'version'	=> $VERSION,
);

Pikabot->spawn;