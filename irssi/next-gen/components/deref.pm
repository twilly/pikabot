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
###
# History:
#


use strict;
use warnings;

use LWP;

# INIT
#   This method is called first, it should do anything it needs to init the
#   compoment... E.G: Modify internal "global" variables, etc.
#   Upon any kind of failure it should "die".
sub INIT () {
  # la la la~
}

# CHANNELS
#   Method should return a list of regexes for current channel to be matched
#   against.  The regexes should make sure not to "capture" anything '(?:)' and
#   should specify case insensitivity if and when they want it '(?i)'.  The
#   regexes can optionally include the use of '^' and '$'.
#   This allows for greater control of the channel inclusion, you can do something
#   as loose as '(?i:anime)' or something as tight as '^(?:#|&)Anime-CHAT$'.
sub CHANNELS () {
  '^#(?i:honobono)$',
  '^#51$',

  # etc
}

sub SIGNALS () {
  # reserved for future use
}

# SETTINGS
#   Method should return a hash with keys of the name you want to store the
#   data under, and values that are array refs of which item 0 is the type (required)
#   and item 1 is the default value (optional).  The keys should use underscores
#   in place of spaces.  The types are listed below:
#     - str (string)
#     - int (integer)
#     - bool (boolean)
#     - time (I don't really know.)
#     - level (Not quite sure, either.)
#     - size (Uh... Yeah.)
sub SETTINGS () {
  'user_agent' => [
    'str',
    'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1',
  ],
  'max_redirect' => [
    'int',
    0,
  ]
}


# TRIGGERS
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
#           0) message (string)
#           1) nick (string)
#           2) address of "nick" (string)
#           3) target (string)
#             ... that's all for now
#     2) server data struct (see irssi docs)
#     3) settings data structure:
#           - Contains a list of the full name of everything registered by
#             the SETTINGS() method.  This way they aren't retrieved unless
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
sub TRIGGERS () {
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
        { 'error' => 'Malformed request' },
      )
    };
    $data->{'server'}->ischannel($data->{'target'}) or
       ($data->{'target'} eq $data->{'nick'} and do {

      $type++;
    });
    defined($data->{'message'}) or do {

      return (
        0,
        [ 'warning' => "$data->{'nick'} sent an empty message." ],
        [ 'send_message' => $target, 'Next time try sending a url, too.', $type ],
      );
    };


    my ($url) = split(/\s+/, $data->{'message'});

    length($url) or do {

      return (
        0,
        [ 'warning' => "$data->{'nick'} sent an apparently null url." ],
        [ 'send_message' => $target, 'I was unable to dereference that.', $type ],

    my ($agent) = LWP::UserAgent->new(
      'max_redirect' => ,
      'agent' => ,
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


    ## NOT FINISHED
  }
}


# My stuff.
#sub whatever ($) {
#  do crap;
#}


# Must be returned, or else the component will not be loaded.
__PACKAGE__;