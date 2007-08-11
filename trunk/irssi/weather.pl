# weather.pl: Weather Channel weather information.
#
# Copyright (C) 2007   Tristan Willy <tristan.willy at gmail.com>
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
use XML::DOM::Lite qw(Parser :constants);

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'weather',
           'description' => 'Weather Channel trigger',
           'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'weather_channels', '');

my %deref_active_chans;
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $deref_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('weather_channels'));
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $deref_active_chans{uc($to)}){
    if($message =~ /^\s*!weather\s+(.+)\s*/i){
      trigger_weather($server, $target, $to, $from, $address, $1);
    }
  }

  return 1;
}

sub trigger_weather {
  my ($server, $target, $to, $from, $address, $where) = @_;

  my $loc_id = get_location_id($server, $target, $where) or return;
  my $weather = get_weather($server, $target, $loc_id) or return;
  $server->command("msg $target Weather near $weather->{location}: $weather->{temp}{F}°F ($weather->{temp}{C}°C) and $weather->{type}.");
}

sub get_location_id {
  my ($server, $target, $where) = @_;
  my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $search = $agent->get('http://xoap.weather.com/search/search?where=' . $where);
  if(not $search->is_success()){
    $server->command("msg $target Failed to get search document. Broken service?");
    return 
  } else {
    # find the ID
    my $search_doc = Parser->parse($search->content())
      or do { $server->command("msg $target Failed to parse search result."); return };
    my ($hits, $loc) = (0, undef);
    map {
      if($_->tagName eq 'loc'){
        $hits++;
        $loc = $_ if not defined $loc;
      }
    } @{$search_doc->documentElement()->childNodes()};
    if($hits < 1){
      $server->command("msg $target Couldn't find \"$where\".");
      return;
    }
    if(defined $loc){
      return $loc->getAttribute("id");
    }
  }
}

sub get_weather {
  my ($server, $target, $loc_id) = @_;
  my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $weather = $agent->get('http://xoap.weather.com/weather/local/' . $loc_id . '?cc=*');
  if(not $weather->is_success()){
    $server->command("msg $target Failed to get search document. Broken service?");
    return;
  } else {
    my $weather_doc = Parser->parse($weather->content());
    my $cc = undef;
    map { $cc = $_ if $_->tagName() eq 'cc' } @{$weather_doc->documentElement()->childNodes()};
    if(not defined $cc){
      $server->command("msg $target Error getting local weather.");
      return;
    }
    my %actions = ( 'obst' => sub { $_[0]->{location} = $_[1] },
                    'tmp'  => sub {
                                $_[0]->{temp}{F} = $_[1];
                                $_[0]->{temp}{C} = sprintf("%.2f", ($_[1] - 32) * (5.0 / 9.0));
                              },
                    't'    => sub { $_[0]->{type} = $_[1] }
                  );
    my %result;
    map {
        $actions{$_->tagName()}->(\%result, $_->firstChild()->nodeValue(), $_) if defined $actions{$_->tagName()};
    } @{$cc->childNodes()};
    return \%result;
  }
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
