#!/usr/bin/env perl
# weather.pl: weather information.
#
# Copyright (C) 2007-2011 Tristan Willy <tristan.willy at gmail.com>
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
use JSON;
use utf8;
use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'weather',
           'description' => 'Weather Underground trigger',
           'license'     => 'GPL v2' );
my %weather_active_chans;
my ($errstr, $bot_key);

# If we're in irssi, load up irssi interface, otherwise call main
if(in_irssi()){
  load_irssi_internals();
} else {
  main();
}


sub in_irssi {
  eval { Irssi::Core::is_static() };
  if($@){
    return 0;
  } else {
    return 1;
  }
}


sub load_irssi_internals  {
  require Irssi;
  Irssi->import;

  Irssi::settings_add_str($IRSSI{'name'}, 'weather_channels', '');
  Irssi::settings_add_str($IRSSI{'name'}, 'weather_key', '');

  load_globals();

  Irssi::signal_add('event privmsg', 'irc_privmsg');
  Irssi::signal_add('setup changed', 'load_globals');
}


sub load_globals {
  map { $weather_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('weather_channels'));
  $bot_key = Irssi::settings_get_str('weather_key');
  if(not $bot_key){
    Irssi::print("Warning: weather script requires an API key");
  }
}


sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $weather_active_chans{uc($to)}){
    if($message =~ /^\s*!weather\s+(.+)\s*/i){
      trigger_weather($server, $target, $to, $from, $address, $1);
    }
  }

  return 1;
}


sub privmsg_error {
  my ($server, $target) = @_; 
  $server->command("msg $target $errstr");
}


sub trigger_weather {
  my ($server, $target, $to, $from, $address, $where) = @_;

  my $loc_id = get_location_id($where)
    or return privmsg_error($server, $target);
  my $weather = get_weather($loc_id, $bot_key)
    or return privmsg_error($server, $target);
  $server->command("msg $target " . english_report($weather));
}


sub get_location_id {
    my ($where) = @_;
    my $agent = LWP::UserAgent->new or die;
    my $search =
        $agent->get('http://autocomplete.wunderground.com/aq?query=' .
                $where . '&format=JSON');
    if(not $search->is_success()){
        $errstr = "Failed to get search document: " . $search->status_line;
        return;
    } else {
        # find the ID
        my $json = JSON->new or die;
        my $doc = $json->decode($search->content())
            or do { $errstr = "Failed to parse search result."; return };
        if(defined $doc->{RESULTS}->[0]->{l}){
            return $doc->{RESULTS}->[0]->{l};
        } else {
            $errstr = "Cannot find $where.";
            return;
        }
    }
}


sub get_weather {
    my ($loc_id, $key) = @_;
    my $agent = LWP::UserAgent->new or die;
    my $weather =
        $agent->get("http://api.wunderground.com/api/$key/conditions/$loc_id.json");
    if(not $weather->is_success()){
        $errstr = "Failed to get weather document: " . $weather->status_line;
        return;
    } else {
        my $json = JSON->new or die;
        my $doc = $json->decode($weather->content())
            or do { $errstr = "Failed to parse search result."; return };
        my $curobs = $doc->{current_observation};
        my %result = (
                'location' => $curobs->{display_location}->{full},
                'temp' => { 'F' => $curobs->{temp_f} },
                'type' => $curobs->{weather},
                'humidity' => $curobs->{relative_humidity},
                );

        # feels-like is windchill. if it doesn't exist, then fill with current temp.
        if($curobs->{windchill_f} ne 'NA'){
            $result{feelslike}{F} = $curobs->{windchill_f};
        } else {
            $result{feelslike}{F} = $result{temp}{F};
        }

        # convert units
        $result{temp}{C} = F_to_C($result{temp}{F});
        $result{feelslike}{C} = F_to_C($result{feelslike}{F});

        return \%result;
    }
}


sub F_to_C {
  return sprintf("%.1f", (shift() - 32) * (5.0 / 9.0));
}


sub english_report {
  my $weather = shift;
  my $report = "Weather near $weather->{location}: $weather->{temp}{F}°F ($weather->{temp}{C}°C)";
  if(abs($weather->{temp}{F} - $weather->{feelslike}{F}) > 7){
    $report .= ", but feels like $weather->{feelslike}{F}°F ($weather->{feelslike}{C}°C),";
  }
  $report .= " and $weather->{type}.";
  if($weather->{humidity} > 60 and
     $weather->{temp}{F} >= 80){
    $report .= " Also, it's really humid ($weather->{humidity}%).";
  }
  return $report;
}


sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}


sub main {
  if($#ARGV < 1){
    warn "I need arguments or to be loaded into irssi.\n";
    warn "Usage: $0 [key] [location]\n";
    exit 1;
  }

  my $key = shift @ARGV;

  my $location = '';
  $location .= "$_ " foreach @ARGV;
  chop($location);
  my $loc_id = get_location_id($location)
      or die "cannot get location id for \"$location\": $errstr";
  my $weather = get_weather($loc_id, $key)
      or die "cannot get weather for location $loc_id: $errstr\n";
  print english_report($weather) . "\n";
  exit 0;
}


