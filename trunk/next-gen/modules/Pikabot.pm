#!/usr/bin/perl -w
package Pikabot;
# Pikabot: The cutest bot you've ever seen.
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
#   2009-04-18:
#     - Implement a method for storing entire bot to file (based
#       on methods provided by "Storable") so that the bot does not
#       need to be completely recompiled inbetween sessions.  This
#       would allow the driver to catch the quit or exit signal,
#       "flash" the bot to the drive (I love the word flash) then
#       continue with the quit/exit.  This could be done completely
#       by the driver, but would be a cool feature to include. :)
#     - (DONE 2009-04-18) Clean up the "_require" method, mainly the error messages.
#     - Think up a better way to use Pikabot::Report with Carp.
#   2009-04-16:
#     - (ACTIVE 2009-04-18) Along with "active channel" support, add "active network"
#       and "active server" etc
#     - (ACTIVE 2009-04-18) For configuring the bot, we could have Pikabot check
#       %main::IRSSI for settings, but that would sorta kill the
#       object-ness of it, maybe have it fall back to checking that?
#     - (DONE 2009-04-17) Add checks to "spawn" method.
#   2009-04-14:
#     - Add checks to "ike" method.
#   2009-04-11:
#     - (MOVED 2009-04-16) Replace spawn checks/config with call to $main::VERSION
#       and %main::IRSSI?  Problems might occur if this module is nested...
#   2009-04-07:
#     - (DROP 2009-04-16) Simplify configuration a little (E.G: For global channels,
#       allow scalar values to be pushed onto the stack.)
#     - (DROP 2009-04-16) possibly move the inclusion of Text::ParseWords out to compile
#       time
#   2009-04-06:
#     - (DONE) fix evil hax in config method
###
# History:
#
#   2009-04-18:
#     - Imported "Storable" module for component configuration.
#     - Dropped "Pikabot::Trigger", "Pikabot::Channel" and "Pikabot::Setting".
#     - Expanded on the assumption from 2009-04-16, "This bot is a weird
#       hybrid of oo and not."  SO, now I'm going to pry right into %main::
#       and look for what I need. :)  Heeeere's Johnny!
#   2009-04-16:
#     - I added a new assumption to code under, it boils down to: "This
#       module will not be nested.  All calls to AUTOLOAD will be from
#       either this module (__PACKAGE__) or it's parent ('main')."
#   2009-04-14:
#     - coded "ike" method, it needs checks to make sure that there
#       are some triggers loaded
#     - tested the new methods, they seem to be working OK
#     - coded the "load" method and two internal methods "_require" and
#       "_exists_setting".  "_reguire" is a custom built require subroutine.
#   2009-04-11:
#     - Forget about global channels for now, just make every trigger state
#       it's channels explicitly.
#     - Started yet another rewrite based on earlier brain waves and some
#       light reading through my big ole' perl black book that I forgot I
#       owned.
#   2009-04-10:
#     - brain wave #2: build my own pseudo require routine for components
#     - brain wave regarding pikabot components: Why make it complex?  Will
#       just use perl modules now.
#   2009-04-08:
#     - reworked "train" and "grab" slightly
#   2009-04-07:
#     - added Text::ParseWords.pm
#     - coded "new", "train", and "grab" methods
#     - dropped config module entirely to go full OO
#   2009-04-06:
#     - config method coded, beware of it's evil


use strict;
use warnings;

use Carp;
use Storable qw(lock_store lock_retrieve);
use Text::ParseWords; # I have to admit, quotewords() is useful.
use Pikabot::Signal;
use Pikabot::Global;
use Pikabot::Report qw(error);

sub AUTOLOAD {
  # Some notes on this routine:
  #   1) It's a bit of a hack.
  #   2) It's very inflexible.
  #   3) It'll do for now. :)

  # First let's make sure this is a signal routine.
  ($AUTOLOAD =~ /@{[ Pikabot::Global->SIGNAL_REGEX ]}/o and
    defined($1)) and do {

    eval '@_ = Pikabot::Signal::' . $1 . '(@_);'; # eval hax... erm evil

    # Was there an error?
    $@ and do {

      # Was it a stupid one?
      $@ =~ /undef.*sub/io and do {

        croak "Undefined subroutine &Pikabot::Signal::$1 called";
      };

      # Was it a serious one?
      croak $@;
    };

    # No errors, let's return what we found.
    return (@_);
  };

  # Dumb error.
  croak "Undefined subroutine &$AUTOLOAD called";
}

our (@ISA, @EXPORT);
my ($PIKA);

BEGIN {
  require Exporter;
  @ISA = qw(Exporter);
  @EXPORT = qw(AUTOLOAD);
}


# External methods and the like.

sub spawn () {
  # This starts up the module, at the moment it
  # uses dirty tricks and funtimes to go about
  # that process....

  my $class = shift;

  # Check if the bot is already spawned.
  defined($PIKA) and do {

    carp error(1, 1);
    return (undef);
  };
  # Check if the required symbol exists.
  exists($main::{Pikabot::Global->BOT_VAR_NAME}) or do {

    croak error(1, 3);
  };
  # Check if the symbol contains a hash...
  exists(%{$main::{Pikabot::Global->BOT_VAR_NAME}}) or do {

    croak error(1, 4);
  };


  # Set $PIKA to the symbol.
  $PIKA = $main::{Pikabot::Global->BOT_VAR_NAME};


  # Make sure their hash has what we need...
  eval {
    foreach my $k (Pikabot::Global->CONFIG_FIELD) {
      exists($PIKA->{$k}) or do {

        die "missing key $k";
      };
      defined($PIKA->{$k}) or do {

        die "undefined key $k";
      };
    }
  };

  $@ and do {

    # Their hash was missing something we needed.
    $@ =~ /(?:missing|undefined) key (\w+)/o and do {

      croak error(1, 5, "\"$1\"");
    };

    # Bad error.
    confess $@;
  };

  # Check if we're going to auto configure.
  exists($PIKA->{'autoconfig'}) and do {

    # Make sure the directory exists.
    -d $PIKA->{'autoconfig'} or do {

      croak error(1, 6);
    };

    # Make sure that the directory is in @INC.  Big problems may
    # occur later on if it isn't, so I'll do this check now.
    THING: {
      foreach my $path (@INC) {
        $PIKA->{'autoconfig'} eq $path and do {

          last THING;
        };
      }

      croak error(1, 7);
    }
  };


  # Now is when things get sketchy! :D  We're going to work right
  # in main's workspace...  For the moment this makes things easier
  # for me.  I still think this bot could be object oriented pretty
  # easy, but I'm limiting "practical applications" of this bot-core
  # to one bot per driver script just because I can.  So, if I'm
  # going as far as to say one bot per script, I'm gonna make sure
  # that there is only one bot in that script by invading it's
  # workspace and looking for a configuration hash, then manipulating
  # it.  Haha...... Evil?  Yes.  Dangerous?  Probably.
  $PIKA->{'tree'} = {};

  # Return something good, might as well.
  return (1);
}

sub load (@) {
  my $class = shift;

  # Make sure the bot is already spawned.
  defined($PIKA) or do {

    croak error(2, 8);
  };


  # Run across the list given...
  foreach my $c (@_) {

    # Make sure that the component's two files are given in a hash.
    (ref($c) eq 'HASH' and
      exists($c->{'file'}) and
        exists($c->{'conf'})) or do {

      croak error(3, 9);
    };

    # Import the component.
    my ($symbol) = _require($c->{'file'});

    # If the component was already loaded, _require returns undef,
    # currently overloading is not supported.
    defined($symbol) or do {

      # Calling "_forget" keeps things safe.
      _forget($c->{'file'});
      croak error(3, 10, $c->{'file'});
    };

    # Grab the name from the returned value of the component.
    my ($name) = _check_component_symbol($symbol);

    # The above "check" returns undef if it fails to match
    # "Pikabot::Global->CMPNNT_REGEX" against the components returned
    # value.
    defined($name) or do {

      _forget($c->{'file'});
      croak error(3, 11);
    };


    # If we are autoconfiguring components, then let's do it! :D
    exists($PIKA->{'autoconfig'}) and do {

      # Now you may (or may not) see why we needed to make sure that
      # the autoconfig directory was already in @INC...
      my $cf = join('/', $PIKA->{'autoconfig'}, $c->{'conf'});

      -f $cf or do {

        lock_store(Pikabot::Global->CONFG_LAYOUT, $cf) or do {

          _forget($c->{'file'});
          croak error(3, 12);
        };
      };
    };


    # Now we start compiling the component.
    eval {

      # At the moment, I guess modules can configure
      # themselves with the BOOT method and Storable.  They
      # should use "lock_retrieve" and "lock_store".  This is
      # not really the best way to go about this, but it'll
      # do for the moment.
      # BOOT must return a false value for failures and a
      # not false value if there isn't any failures.
      $symbol->BOOT(_lookup($c->{'conf'})) or do {

        die 'boot failure';
      };

      # Here is the "layout" that will be stuck in main's
      # workspace.
      $PIKA->{'tree'}->{$name} = {
        'routine'   => {
          $symbol->STUFF,
        },
        'location'  => {
          'file'  => $c->{'file'},
          'conf'  => $c->{'conf'},
        },
      };

      # Make sure that there is some stuff to work with...
      keys(%{$PIKA->{'tree'}->{$name}->{'routine'}}) > 0 or do {

        die 'no routines found';
      };
    };

    $@ and do {

      $@ =~ /(boot failure|no routines found)/io and do {

        _forget($c->{'file'});
        croak error(3, 13, "\u$1");
      };

      confess $@;
    };







# Internal methods, and the like.

sub _require ($;$) {
  # This is basically a slightly hacked verion of
  # perl's own require method.  I say "slightly"
  # because only what is returned is modified, the
  # rest is pretty much the same! :D
  # One additional modification is overloading, it's
  # not 100% ready for use, but it's getting there.

  my ($file, $overload) = @_;

  exists($INC{$file}) and do {

      $INC{$file} or do {

      croak 'Compilation failed at %INC check';
    };

    (defined($overload) and
      $overload) or do {

      return (undef);
    };
  };

  foreach my $path (@INC) {
    my $fullfile = "$path/$file";

    -f $fullfile or do {

      next;
    };

    $INC{$file} = $fullfile;
    my $package = do $fullfile;

    $@ and do {

      $INC{$file} = undef;

      croak $@;
    };

    (defined($package) and
      length($package) and
        $package) or do {

      delete($INC{$file});

      croak "$file did not return a true value";
    };


    return ($package);
  }

  croak "Can't find $file in \@INC";
}

sub _lookup ($) {
  # This is basically a hacked verion of perl's own
  # require method.  All it does is look for a file
  # in @INC and, if found, returns the full path.
  # I use it to keep non-perl stuff out of %INC, plus
  # with this routine is not really a cycle waster, so
  # it'll be quick anyway.

  my ($file) = @_;

  foreach my $path (@INC) {
    my $fullfile = "$path/$file";

    -f $fullfile or do {

      next;
    };

    -r $fullfile or do {

      carp "Unable to read $fullfile: $!";
      next;
    };

    return ($fullfile);
  }

  croak "Can't find $file in \@INC";
}

sub _forget ($;$) {
  # Essentially a cheap "unrequire" routine.

  my ($file, $do) = @_;

  exists($INC{$file}) or do {

    croak "Unable to find $file in \%INC";
  };


  if (defined($do) and $do) {
    delete($INC{$file});
  } else {
    $INC{$file} = undef;
  }

  return (1);
}

sub _exists_setting ($) {
  # In scalar context returns the number of matches (if
  # that number is higher than one, you have a problem
  # with your globals)... In list context returns what
  # matched.

  my ($given) = @_;

  return (grep { $given eq $_ } Pikabot::Global->SETTING_TYPE);
}

sub _check_component_symbol ($) {
  # This just makes sure the user has built his or
  # her Pikabot components correctly.

  my ($given) = @_;

  ($given =~ /@{[ Pikabot::Global->CMPNNT_REGEX ]}/o and
    defined($1)) and do {

    return ($1);
  };

  return (undef);
}

sub _symbol_to_setting ($$;$) {
  # Quick little hack to turn a symbol and a
  # setting into a setting string that Irssi
  # will not mind.
  # Optionally calls lc() on it.

  my ($sym, $set, $low) = @_;

  (defined($sym) and
    defined($set)) or do {

    return (undef);
  };


  my $setting = "${sym}_${set}";

  $setting =~ s/[^A-Za-z0-9]/_/go;
  $setting =~ s/_+/_/go;


  return ($low ? lc($setting) : $setting);
}


__PACKAGE__;