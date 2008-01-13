# autovoice.pl: irssi autovoice (+v) script for fileservers.
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
use LWP;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'autovoice',
           'description' => 'auto-voice fservs',
           'license'     => 'GPL v2' );

# What channels are we allowed to monitor?
Irssi::settings_add_str($IRSSI{'name'}, 'autovoice_channels', '');
# update interval: time, in minutes, between !list. cache items
# invalidate after this interval as well. Default: 12 hours
Irssi::settings_add_int($IRSSI{'name'}, 'autovoice_update_interval', 60*12);

my (%active_chans, $update_interval, %voice_cache);
load_globals();

Irssi::signal_add('message irc notice', 'irc_notice');
Irssi::signal_add('setup changed', 'load_globals');
Irssi::signal_add('massjoin', 'irc_massjoin');

sub load_globals {
  map { $active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('autovoice_channels'));
  $update_interval = Irssi::settings_get_int('autovoice_update_interval');
}

sub irc_notice {
  my ($server, $message, $from, $address, $to) = @_;
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  if(is_fserv_notice($message)){
    $voice_cache{$server}{$from} = time();
  }
}

# When we know someone needs voice then give it to them
# without waiting until the next !list
sub irc_join {
}

# same as above, but for many people
sub irc_massjoin {
  my ($channel, $nicks_aref) = @_;

  if(not defined $active_chans{uc($channel->{name})} or
     not $channel->{chanop}){
     return;
  }

  # Search through nicks for matches in the cache
  my @to_voice;
  # invalid entry if older than update interval
  my $oldest_timestamp = time() - ($update_interval * 60);
  map {
    if($voice_cache{$channel->{server}}{$_->{nick}} >= $oldest_timestamp){
      push @to_voice, $_->{nick} if not ($_->{op} or $_->{halfop} or $_->{voice});
    }
  } (@{$nicks_aref});

  # voice three people at a time
  while(my @set = splice(@to_voice, 0, 3)){ 
    $channel->{server}->command("mode $channel->{name} +v @set");
  }
}

sub is_fserv_notice {
  my $msg = shift;

  return 1
    if $msg =~ /(fserv\s+active)|(file\s+server\s+online)|(XDCC)/io;

  return 0;
}

