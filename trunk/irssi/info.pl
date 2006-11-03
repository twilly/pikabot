# info.pl: pikabot status and information irssi module
#
# Copyright (C) 2006   Tristan Willy <tristan.willy at gmail.com>
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
use Text::ParseWords;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.1';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'info',
           'description' => 'pikabot status and information',
           'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'info_channels', '');
Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('message irc notice', 'irc_notice');
Irssi::signal_add('setup changed', 'load_globals');

my (%active_chans, $starttime);
$starttime = time();

sub load_globals {
  map {
    $active_chans{uc($_)} = 1;
  } quotewords(',', 0, Irssi::settings_get_str('info_channels'));
}

sub irc_notice {
  irc_genmsg(@_, 'notice');
}

sub irc_privmsg {
  irc_genmsg(@_, 'msg');
}

sub irc_genmsg {
  my ($server, $data, $from, $address, $cmd) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  if(uc($to) eq uc($me) or $active_chans{uc($to)}){
    if($message =~ /^[^!]*!uptime/oi){
      $server->command($cmd . " $target " . trigger_uptime());
    } elsif($message =~ /^[^!]*!info/oi) {
      $server->command($cmd . " $target " . trigger_info());
    }
  }

  return 1;
}

sub trigger_info {
  return "\x0313PikaBot <http://code.google.com/p/pikabot/> SVN Revision " . '$Revision$';
}

sub trigger_uptime {
  my $script_uptime = secs2texttime(time() - $starttime);
  my $local_uptime = '?:?';
  if(open(FH, '/proc/uptime')){
    my $l = <FH>;
    if($l =~ /^(\d+\.\d+)/){
      $local_uptime = secs2texttime(int($1 + 0.5));
    }
    close(FH);
  }
  return "\x0306Bot Uptime [$script_uptime]\x0310 " .
         "System Uptime [$local_uptime]";
}

sub secs2texttime {
  my $sec = shift;
  $sec = int($sec + 0.5); # round second
  my $days = int($sec / 86400); $sec %= 86400;
  my $hours = int($sec / 3600); $sec %= 3600;
  my $minutes = int($sec / 60); $sec %= 60;

  my $base = sprintf("%d:%02d:%02d", $hours, $minutes, $sec);

  if($days <= 0){
    return $base;
  }

  if($days != 1){
    return sprintf("%d days ", $days) . $base;
  } else {
    return ("1 day " . $base);
  }

  return "~bug~";
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}

