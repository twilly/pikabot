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
###
# History
#


use strict;
use warnings;
use Carp;

use Text::ParseWords;
use Pikabot::Global;


sub spawn {
  my $class = shift;
  my %pika = @_;

  foreach my $f (Pikabot::Global->CONFIG_FIELD) {
    (exists($pika{$f}) and
      defined($pika{$f})) or do {

      croak 'Invalid config';
    };
  }

  eval sprintf(
    'use %s;',
    $pika{'core'},
  );

  $@ and do {
    if ($@ =~ /@{[ Pikabot::Global->BAD_CORE_GEX ]}/) {
      local($@) = undef;

      eval sprintf(
        'use %s::%s;'
        __PACKAGE__,
        $pika{'core'},
      );

      $@ and do {
        $@ =~ /@{[ Pikabot::Global->BAD_CORE_GEX ]}/ and do {
          croak "Unable to locate core $pika{'core'}";
        };

        confess $@;
      };
    } else {
      confess $@;
    }
  };

  return (bless \%pika, $class);
}

sub load {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or do {
    die;
  };
  @_ > 0 or do {
    croak 'Nothing to load';
  };

  foreach my $f (@_) {
    exists($INC{$f}) and do {
      $INC{$f} or do {
        croak 'Compilation failed at %INC check';
      };

      next;
    };

    foreach my $p (@INC) {
      my $file = "$p/$f";

      -f $file or do {
        next;
      };

      $INC{$f} = $file;

      my $s = do $file;

      $@ and do {
        $INC{$f} = undef;
        croak $@;
      };
      (defined($s) and
        length($s)) or do {

        delete($INC{$f});
        croak "$f did not return a true value";
      };


    }



sub train {
  my $pika = shift;

  ref($pika) eq __PACKAGE__ or do {

    die;
  };


  # NOT CODEEEEEEDDDDDD
}






    my $return = do $fullfile;

    $@ and do {

      $INC{$file} = undef;
      die $@;
    };


    (defined($return) and
      length($return)) or do {

      delete($INC{$file});
      die "$file did not return a true value";
    };

    return ($return);
  }

  die "Can't find $file in \@INC";
}

sub _conforms ($) {
  my ($symbol) = @_;

  return ($symbol =~ /^@{[ Pikabot::Global->CMPNNT_REGEX ]}$/o);
}