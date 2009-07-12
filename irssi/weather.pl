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
use XML::DOM::Lite qw(Parser :constants);
use vars qw($VERSION %IRSSI);
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'weather',
           'description' => 'Weather Channel trigger',
           'license'     => 'GPL v2' );
my %weather_active_chans;
my $errstr;

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

  load_globals();

  Irssi::signal_add('event privmsg', 'irc_privmsg');
  Irssi::signal_add('setup changed', 'load_globals');
}


sub load_globals {
  map { $weather_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('weather_channels'));
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

  my $loc_id = get_location_id($where) or return privmsg_error($server, $target);
  my $weather = get_weather($loc_id) or return privmsg_error($server, $target);
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
    my $search_doc = Parser->parse($search->content())
      or do { $errstr = "Failed to parse search result."; return };
    my ($hits, $loc) = (0, undef);
    map {
      if($_->tagName eq 'loc'){
        $hits++;
        $loc = $_ if not defined $loc;
      }
    } @{$search_doc->documentElement()->childNodes()};
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
  my ($loc_id) = @_;
  my $agent = LWP::UserAgent->new('agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $weather = $agent->get('http://xoap.weather.com/weather/local/' . $loc_id . '?cc=*');
  if(not $weather->is_success()){
    $errstr = "Failed to get search document. Broken service?";
    return;
  } else {
    my $weather_doc = Parser->parse($weather->content());
    my $cc = undef;
    map { $cc = $_ if $_->tagName() eq 'cc' } @{$weather_doc->documentElement()->childNodes()};
    if(not defined $cc){
      $errstr = "Error getting local weather.";
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
        $actions{$_->tagName()}->(\%result, $_->firstChild()->nodeValue(), $_) if defined $actions{$_->tagName()};
        # print "no action for child node \"" . $_->tagName() . "\"\n" if not defined $actions{$_->tagName()};
    } @{$cc->childNodes()};
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
  if($#ARGV < 0){
    warn "I need arguments or to be loaded into irssi.\n";
    exit 1;
  }

  my $location = '';
  $location .= "$_ " foreach @ARGV;
  chop($location);
  my $loc_id = get_location_id($location) or die "cannot get location id";
  my $weather = get_weather($loc_id) or die "cannot get weather";
  use Data::Dumper;
  print Dumper($weather);
  print english_report($weather) . "\n";
  exit 0;
}


