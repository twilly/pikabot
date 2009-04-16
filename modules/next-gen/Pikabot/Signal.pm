#!/usr/bin/perl -w
package Pikabot::Signal;
# Pikabot::Signal: Standard parser thing for Irssi signals.
#
# Copyright (C) 2009  Justin Lee  < kool.name at gmail.com >
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
#     - add support for "MESSAGE IRC *" events and other popular
#       signals
###
# History:
#
#   2009-04-14:
#     - coded all "MESSAGE *" events

use strict;
use warnings;

use SelfLoader;


__PACKAGE__;


__DATA__

sub message_public {
  my ($server, $message, $nick, $address, $target) = @_;

  return (
    {
      'server'  => $server,
      'message' => $message,
      'nick'    => $nick,
      'address' => $address,
      'target'  => $target,
      'type'    => 'message',
    }
  );
}

sub message_private {
  my ($server, $message, $nick, $address) = @_;

  return (
    {
      'server'  => $server,
      'message' => $message,
      'nick'    => $nick,
      'address' => $address,
      'target'  => $nick,
      'type'    => 'message',
    }
  );
}

sub message_own_public {
  my ($server, $message, $target) = @_;

  return (
    {
      'server'  => $server,
      'message' => $message,
      'nick'    => $server->{'nick'},
      'target'  => $target,
      'type'    => 'message',
    }
  );
}

sub message_own_private {
  my ($server, $message, $target, $otarget) = @_;

  $target ne $otarget and do {

    # I don't know what it means when they aren't the same. >_>
    warn "HEY, HERE IT IS: $target != $otarget\n";
  };

  return (
    {
      'server'  => $server,
      'message' => $message,
      'nick'    => $server->{'nick'},
      'target'  => $target,
      'type'    => 'message',
    }
  );
}

sub message_join {
  my ($server, $target, $nick, $address) = @_;

  return (
    {
      'server'  => $server,
      'nick'    => $nick
      'address' => $address,
      'target'  => $target,
      'type'    => 'enter',
    }
  );
}

sub message_part {
  my ($server, $target, $nick, $address, $message) = @_;

  return (
    {
      'server'  => $server,
      'address' => $address,
      'nick'    => $nick,
      'message' => $message,
      'target'  => $target,
      'type'    => 'exit',
    }
  );
}

sub message_quit {
  my ($server, $nick, $address, $message) = @_;

  return (
    {
      'server'  => $server,
      'nick'    => $nick,
      'address' => $address,
      'message' => $message,
      'type'    => 'quit',
    }
  );
}

sub message_kick {
  my ($server, $target, $them, $nick, $address, $message) = @_;

  return (
    {
      'server'  => $server,
      'nick'    => $nick,
      'address' => $address,
      'target'  => $target,
      'message' => $message,
      'kicked'  => $them,
      'type'    => 'kick',
    }
  );
}

sub message_nick {
  my ($server, $nnick, $onick, $address) = @_;

  return (
    {
      'server'  => $server,
      'nick'    => {
        'old' => $onick,
        'new' => $nnick,
      },
      'address' => $address,
      'type'    => 'nick',
    }
  );
}

sub message_own_nick {
  my ($server, $nnick, $onick, $address) = @_;

  return (
    {
      'server'  => $server,
      'nick'    => {
        'old' => $onick,
        'new' => $nnick,
      },
      'address' => $address,
      'type'    => 'nick',
    }
  );
}

sub message_topic {
  my ($server, $target, $topic, $nick, $address) = @_;

  return (
    {
      'server'  => $server,
      'target'  => $target,
      'topic'   => $topic,
      'nick'    => $nick,
      'address' => $address,
      'type'    => 'topic',
    }
  );
}

sub message_invite {
  my ($server, $target, $topic, $nick, $address) = @_;

  return (
    {
      'server'  => $server,
      'topic'   => $topic,
      'target'  => $target,
      'nick'    => $nick,
      'address' => $address,
      'type'    => 'invite',
    }
  );
}