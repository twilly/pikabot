#!/usr/bin/perl -w
package Pikabot::Component::Deref;
# deref: Dereferencing module for Pikabot.
#
# Copyright (C) 2009  Authors @ http://pikabot.googlecode.com/
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
#   2009-04-21:
#     - Complete re-code.

use strict;
use warnings;

use LWP;

sub BOOT () {
  # I don't care how this hash gets here, but it has to be here.
  # "BOOT" can look for an external file, whatever.  As long as
  # "BOOT" returns an anonymous hash with this stuff in it.
  # Note that settings in Irssi will override these...  Which
  # makes them DEFAULTS. :)
  {
    # REQUIRED
    'setting' => {
      'max_redirect' => [
        'int',
        0,
      ],
      'user_agent' => [
        'str',
        'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1',
      ],
    },
    'active' => {
      'aniverse' => [ '#51' ],
      'ibo' => [],
      '' => [ '#honobono' ],
    },
    # OPTIONAL
    'trigger' => {
      '(?i:deref(?:erence))' => \&trigger,
    }
    'command' => {
      '(?i:deref(?:erence))' => \&command,
    }
  }
}

sub trigger {
  my ($trigger, $target, $message, $stack, $setting) = @_;
  my ($url) = split(/\s+/, $message, 2);

  $target = $stack->{'target'};

  my ($redir) = deref($url, $setting->{'max_redirect'}, $setting->{'user_agent'});

  defined($redir) or do {

    return (
      # error
    );
  };

  return (
    # not error
  );
}

sub command {
  my ($whatever) = @_;
  # do crap
}

sub deref ($$$) {
  my ($u, $r, $a) = @_;

  # do crap
}


__PACKAGE__;