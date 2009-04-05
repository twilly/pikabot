#/usr/bin/perl -w

use strict;
use warnings;

use lib '/home/user/library/perl';

use Irssi;
use Irssi::Trigger;

# some globals
sub MAIN_DIRECTORY () { '/home/user/.irssi' }
sub COMPONENT_DIRECTORY () { MAIN_DIRECTORY . '/scripts/pikabot' }
sub SCRIPT_NAME () { 'pikabot next-gen' }

use vars qw($VERSION %IRSSI $TRIGGER);

$VERSION = '0.01';

%IRSSI = (
  'authors' => 'Tristan Willy, Justin Lee, Andreas Högström',
  'contact' => 'tristan.willy, kool.name, superjojo at gmail.com',
  'name'    => SCRIPT_NAME,
  'description' => 'A cute bot for irssi!  It does various silly things.',
  'license' => 'GNU GPL v2',
);

# create the trigger-parser
$TRIGGER = Irssi::Trigger->new(
  {
    'PARSER'    => 'MESSAGE',
    'OVERLOADING'   => 1,
    'GLOBAL CHANNELS' => [
      '(?i:honobono)',
    ],
  },
);

print SCRIPT_NAME, ": Object created.";

# find the components
opendir(CMP, COMPONENT_DIRECTORY) or
  die SCRIPT_NAME, ": $!";

my %trigger = map {
  my $file = COMPONENT_DIRECTORY . "/$_";
  my ($key, $val) = do $file;

  $key => $val
} grep {
  not -d and /\.bm$/io # .bm == bot module :P
} readdir(CMP);

closedir(CMP) or
  die SCRIPT_NAME, ": $!";

print SCRIPT_NAME, ': Components found: ', scalar keys(%trigger);

# register the components
$TRIGGER->register->trigger(
  {
    %trigger
  },
);

# free some space
undef(%trigger);

# core
sub trigger {
  my ($status, @info) = $TRIGGER->gazelle(@_);

  defined($status) or
    return;

  $status and do {
    if ($info[3] eq $info[5]) {
      print SCRIPT_NAME, ": Private $info[0] from $info[3] successful.";
    } else {
      print SCRIPT_NAME, ": Public $info[0] from $info[3] successful.";
    }

    return;
  };

  print SCRIPT_NAME, ": $info[0] from $info[3] was not successful.";
}

# initialize the trigger system
$TRIGGER->ike;

# add the signals
Irssi::signal_add('message public', 'trigger');
Irssi::signal_add('message private', 'trigger');
