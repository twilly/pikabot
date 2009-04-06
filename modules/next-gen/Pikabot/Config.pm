#!/usr/bin/perl -w
package Pikabot::Config;
# Pikabot::Config: The cutest bot you've ever seen's config.
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
#     - maybe replace this module with something else entirely?
###
# History:
#
#   2009-04-06:
#     - added various fields
#     - initial layout finished


use strict;
use warnings;

use Pikabot::Reports qw(ERROR);

#our (@ISA, @EXPORT_OK);
#BEGIN {
#  require Exporter;
#  @ISA = qw(Exporter);
#  @EXPORT_OK = qw(CONFIG);
#}

# inlined constants
sub SECTION_NAME () { 'Config' }


our (
  $CONFIGED,

  # Irssi settings_get_*() options
  $IRSSI_SETTINGS_USE,
  $IRSSI_SETTINGS_OVERLOAD_DRIVER,

  # Vanity options
  $BOT_NAME,
  $BOT_VERSION,
  $BOT_AUTHORS,

  # Settings
  $COMPONENT_DIRECTORY,
  $GLOBAL_CHANNELS,
) = (
  0,

  # Irssi settings_get_*() options
  0,
  0,

  # Vanity options
  'Pikabot',
  '',
  { # authors
    'Justin Lee' => 'kool.name at gmail.com',
    'Tristan Willy' => 'tristan.willy at gmail.com',
    'Andreas Högström' => 'superjojo at gmail.com',
  },

  # Settings
  undef,
  [],
);


'Pikachu!';