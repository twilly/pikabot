#!/usr/bin/perl -w
package Pikabot::Component::Deref;
# deref: Dereferencing module for Pikabot.  This is an example of Pikabot's
#        component's coding standard, I guess.
#
# Copyright (C) 2009  Justin Lee  < kool.name at gmail.com >
# Some Code Copyright (C) 2006  Tristan Willy  < tristan.willy at gmail.com >
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
#   2009-04-14:
#     - Move "$type" check (for send_message) out to driver or Pikabot?
###
# History:
#
#   2009-04-16:
#     - Removed setting, signal, and channel boot methods... Now pc will be
#       happy, right?   I think they'll get moved into a configuration file
#       or be completely managed by the driver script... Who knows.
#   2009-04-14:
#     - base coding done


use strict;
use warnings;

use LWP;
#use whatever::you::want;

sub BOOT () {
  # BOOT - required package method
  #   Method should return a true value, I don't care what.  It should also die()
  #   if it runs into something it doesn't like... Please include a helpful
  #   message as it will be passed along to the user.
  #   I'm still not quite sure what to use this for, probably compile time
  #   configuration such as: Making sure a user has a required database setup,
  #   or has a "/proc/uptime" that is readable... I dunno.

  return (1);
}

sub TRIGGERS () {
  # TRIGGERS - required package method
  #   Method should return one or more hash entries with trigger matching patterns
  #   as the keys and code references for their values.  The patterns may include
  #   one "capture" if they're intended for "ninja use"...  That is to say, if
  #   someone private messages the bot a command that has a channel as it's first
  #   argument then you could capture it for setting "$target".... Which would
  #   look something like: ^\s*!(?i:huggle(?:-glomp)?(?:s|z)?)\s*((?:#|&)\S+)?
  #   The value set to $1 will be checked first against $target, if they match
  #   then it will be left in the string, if not it will be checked against the
  #   trigger's channel list.  If it's found then it will be sent to that channel,
  #   if it isn't found the user will be yelled at.  If the ninja mode is not
  #   provided by a trigger, and $target is not set, then Pikabot will assume it
  #   is from a private message and set $target to $nick.  (This assumption may
  #   as the script evolves.
  #
  #   The input structure is something like:
  #     0) trigger caught (string)
  #     1) trigger data structure:
  #           - message => message string
  #           - nick => user who triggered the trigger
  #           - address => that user's address
  #           - target => where it's headed
  #           - server => irssi server_rec
  #             ... that's all for now
  #     2) settings data structure:
  #           - Contains a hash of MY NAMES for the settings and their
  #             full name in Irssi for everything that was registered with
  #             the SETTINGS() method.  This way stuff isn't retrieved unless
  #             it's neccessary.  In the future this may be changed so that
  #             Pikabot (or the driver) has to grab them, but for now this
  #             seems like the best approach.
  #
  #   The return structure is:
  #     0) success/fail (boolean)
  #     1+) a list of array refs with things to do, in order... the structure is
  #         something like:
  #           0) thing to do (string)
  #           1+) things that the thing needs to know (whatever they are)
  #         Supported things are:
  #           - ["send_message" => $target, $message, $type (0 == chan, 1 == nick)]
  #           - ["server_command" => $cmd_string (the '/' is not required)]
  #           - ["print" => $string, $level (optional)]
  #           - ["error" => $string, $level (optional)] (this is a wrapper for print)
  #           - ["warning" => $string, $level (optional)] (see error)
  #
  #   Special note on trigger data structure:
  #     For the time being Pikabot can only really deal with "MESSAGE PUBLIC"
  #     "MESSAGE PRIVATE" events in an effective way.  In the future I think
  #     the data structure could become a hash and Pikabot could just check
  #     for things it can modify or something... Let me give a ...BASIC... example:
  #       does target exist?
  #         YES:
  #           goto send_data
  #         NO:
  #           does nick exists?
  #             YES:
  #               set target to nick
  #               goto send_data
  #             NO:
  #               does server_rec exist?
  #                 YES:
  #                   ...
  #       label:send_data
  #       ...

  '^\s*!(?i:deref(?:erence)?)' => sub {
    my ($trigger, $data, $setting) = @_;
    my $type = 0;

    # For now, all triggers should make sure they've
    # got everything they need.
    (exists($data->{'server'}) and
      exists($data->{'nick'}) and
        exists($data->{'message'}) and
          exists($data->{'target'})) or do {

      return (
        0,
        [ 'error' => 'Malformed request' ],
      )
    };
    # Quick little hack to get the type for send_message...
    $data->{'server'}->ischannel($data->{'target'}) or
       ($data->{'target'} eq $data->{'nick'} and do {

      $type++;
    });
    # Make sure there's something to deref.
    defined($data->{'message'}) or do {

      return (
        0,
        [ 'warning' => "$data->{'nick'} sent an empty message." ],
        [ 'send_message' => $target, 'Next time try sending a url, too.', $type ],
      );
    };
    # Make sure the user_agent setting is available in Irssi.
    exists($setting->{'user_agent'}) or do {

      return (
        0,
        [ 'error' => 'Couldn\'t find "user_agent" key' ],
      );
    };
    # Make sure the max_redirect setting is available in Irssi.
    exists($setting->{'max_redirect'}) or do {

      return (
        0,
        [ 'error' => 'Couldn\'t find "max_redirect" key' ],
      );
    };


    # Grab the URL.
    my ($url) = split(/\s+/, $data->{'message'});

    # Make sure it's got something in it.
    length($url) or do {

      return (
        0,
        [ 'warning' => "$data->{'nick'} sent an apparently null url." ],
        [ 'send_message' => $target, 'I was unable to dereference that.', $type ],
      )
    };

    # Setup the user agent for LWP.
    my ($agent) = LWP::UserAgent->new(
      'max_redirect' => Irssi::settings_get_int($setting->{'max_redirect'}),
      'agent' => Irssi::settings_get_str($setting->{'user_agent'}),
    );

    my ($r) = $agent->get($url);

    ($r->code == 302 or
      $r->code == 301) or do {

      return (
        0,
        [ 'warning' => "Couldn't deref: $url" ],
        [ 'send_message' => $target, 'I was unable to dereference your request.', $type ],
      );
    };


    return (
      1,
      [ 'print' => "Dereferenced $url for $nick." ],
      [ 'send_message' => $target, 'Location: ' . $r->header('Location'), $type ],
    );
  }
}


#sub whatever ($) {
#  do crap;
#}


# Must be returned, or else the component will not be loaded.
__PACKAGE__;