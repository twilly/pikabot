#/usr/bin/perl -w
# bot.pl: A bot for Irssi that uses a modular trigger system.
#
# Copyright (C) 2009   Justin Lee <kool.name at gmail.com>
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


use strict;
use warnings;

use lib '/home/user/library/perl';

use Irssi;
use Irssi::Trigger;
use vars qw($VERSION %IRSSI $TRIGGER);


# some globals
sub MAIN_DIRECTORY () { '/home/user/.irssi' }
sub COMPONENT_DIRECTORY () { MAIN_DIRECTORY . '/scripts/pikabot' }
sub BOT_NAME () { 'pikabot' }

# irssi info
$VERSION = '0.' . '0' x 30 . '1'; # ha! ha!

%IRSSI = (
  'authors'     => 'Justin Lee',
  'contact'     => 'kool.name at gmail.com',
  'name'        => BOT_NAME,
  'description' => 'A cute bot for irssi!  It does various silly things.',
  'license'     => 'GNU GPL v2',
);


# create the trigger-parser, if I don't include it in use vars irssi throws warnings
$TRIGGER = Irssi::Trigger->new(
  {
    'PARSER'          => 'MESSAGE',
    'OVERLOADING'     => 1,
    'GLOBAL CHANNELS' => [
      '(?i:51)',
      '(?i:honobono)',
    ],
  },
);

print BOT_NAME, ": Object created.";


# find the components
opendir(CMP, COMPONENT_DIRECTORY) or
  die BOT_NAME, ": $!";

my %trigger = map {
  my $file = COMPONENT_DIRECTORY . "/$_";
  my ($key, $val) = do $file;

  $key => $val
} grep {
  not -d and /\.bm$/io # .bm == bot module :P
} readdir(CMP);

closedir(CMP) or
  die BOT_NAME, ": $!";

print BOT_NAME, ': Components found: ', scalar keys(%trigger), "";


# register the triggers
$TRIGGER->register->trigger(
  {
    %trigger
  },
);

# free some space
undef(%trigger);


# core thing
sub trigger {
  my ($status) = $TRIGGER->gazelle(@_);

  print BOT_NAME, ': Trigger was ', $status ? "successful." : "unsuccessful.";
}


# initialize the trigger thing
$TRIGGER->ike;


# add signals!
Irssi::signal_add('message public', 'trigger');
Irssi::signal_add('message private', 'trigger');
