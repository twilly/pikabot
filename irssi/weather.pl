#!/usr/bin/env perl
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
use XML::DOM;
use utf8;
use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'weather',
           'description' => 'Weather Channel trigger',
           'license'     => 'GPL v2' );
my %weather_active_chans;
my ($errstr, $bot_pid, $bot_key);

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
  Irssi::settings_add_str($IRSSI{'name'}, 'weather_partner_id', '');
  Irssi::settings_add_str($IRSSI{'name'}, 'weather_key', '');

  load_globals();

  Irssi::signal_add('event privmsg', 'irc_privmsg');
  Irssi::signal_add('setup changed', 'load_globals');
}


sub load_globals {
  map { $weather_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('weather_channels'));
  $bot_pid = Irssi::settings_get_str('weather_partner_id');
  $bot_key = Irssi::settings_get_str('weather_key');
  if(not $bot_pid or not $bot_key){
    Irssi::print("Warning: weather script requires partner_id and " .
        "key settings");
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
  my $weather = get_weather($loc_id, $bot_pid, $bot_key)
    or return privmsg_error($server, $target);
  $server->command("msg $target " . english_report($weather));
}


sub get_location_id {
  my ($where) = @_;
  my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $search = $agent->get('http://xoap.weather.com/search/search?where=' . $where);
  if(not $search->is_success()){
    $errstr = "Failed to get search document. Broken service?";
    return;
  } else {
    # find the ID
    my $parser = new XML::DOM::Parser;
    my $search_doc = $parser->parse($search->content())
      or do { $errstr = "Failed to parse search result."; return };
    my ($hits, $loc) = (0, undef);
    map {
      if($_->getNodeName() eq 'loc'){
        $hits++;
        $loc = $_ if not defined $loc;
      }
    } @{$search_doc->getDocumentElement()->getChildNodes()};
    if($hits < 1){
      $errstr = "Couldn't find \"$where\".";
      return;
    }
    if(defined $loc){
      return $loc->getAttribute("id");
    }
  }
}


sub get_weather {
  my ($loc_id, $pid, $key) = @_;
  my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $weather = $agent->get('http://xoap.weather.com/weather/local/' .
          $loc_id . "?link=xoap&prod=xoap&par=$pid&key=$key&cc=");
  if(not $weather->is_success()){
    $errstr = "Failed to get search document. Broken service?";
    return;
  } else {
    my $parser = new XML::DOM::Parser;
    my $weather_doc = $parser->parse($weather->content());
    my ($cc, $err);
    foreach (@{$weather_doc->getDocumentElement()->getChildNodes()}){
        if($_->getNodeName() eq 'cc'){
            $cc = $_;
        }
        if($_->getNodeName() eq 'err'){
            $err = $_;
        }
    }
    if(not defined $cc){
        if(defined $err){
            $errstr = $err->getFirstChild->getNodeValue();
        } else {
            $errstr = "Error getting local weather.";
        }
      return;
    }
    my %actions = ( 'obst' => sub { $_[0]->{location} = $_[1] },
                    'tmp'  => sub { $_[0]->{temp}{F} = $_[1];
                                    $_[0]->{temp}{C} = F_to_C($_[1]); },
                    't'    => sub { $_[0]->{type} = $_[1] },
                    'flik' => sub { $_[0]->{feelslike}{F} = $_[1];
                                    $_[0]->{feelslike}{C} = F_to_C($_[1]); },
                    'hmid' => sub { $_[0]->{humidity} = $_[1]; }
                  );
    my %result;
    map {
        if(defined $actions{$_->getNodeName()}){
            $actions{$_->getNodeName()}->(\%result, $_->getFirstChild()->getNodeValue(), $_)
        }
    } @{$cc->getChildNodes()};
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
  if($#ARGV < 2){
    warn "I need arguments or to be loaded into irssi.\n";
    warn "Usage: $0 [partner ID] [key] [location]\n";
    exit 1;
  }

  my $pid = shift @ARGV;
  my $key = shift @ARGV;

  my $location = '';
  $location .= "$_ " foreach @ARGV;
  chop($location);
  my $loc_id = get_location_id($location)
      or die "cannot get location id for \"$location\"";
  my $weather = get_weather($loc_id, $pid, $key)
      or die "cannot get weather for location $loc_id: $errstr\n";
  use Data::Dumper;
  print Dumper($weather);
  print english_report($weather) . "\n";
  exit 0;
}


