#!/usr/bin/perl -w
package anidb::Cacher;
# anidb::Cacher.pm:
#   SQL cache base for an AniDB-like system.
#
# Copyright (C) 2009  Justin "idiot" Lee  <kool.name at gmail.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.


use strict;
use warnings;


# Internals~

sub _statementify($) {
  uc([caller]->[3]) =~ /[^\:\:]+$/ or do {
    return (undef);
  };

  my ($caller, $state) = ($1, @_);

  $state =~ s/^\s*/${caller}_/;
  $state =~ s/\s+$//;
  $state =~ s/\s+/_/g;

  return (uc($state));
}


# Methods~

sub spawn {
  my ($class, $dbh, $type) = @_;

  $type = join('::', __PACKAGE__, $type);

  eval qq{
    require $type;
  };
  $@ and do {
    warn, return (undef);
  };

  return (
    bless (
      {
        DBH => $dbh,
        Statements => $type
      },
      $class
    )
  );
}

sub new {
  shift->spawn(@_)
}

sub purge {
  my ($self, $purge) = splice(@_, 0, 2);

  $purge = _statementify($purge) or do {
    warn, return (undef);
  };

  eval {
    $self->{DBH}->do(
      $self->{Statement}->$purge,
      ref($_[0]) eq 'HASH'
        ? shift(@_)
        : undef,
      @_
    );
    $self->{DBH}->commit;
  };
  $@ and do {
    warn $@;
    $self->{DBH}->rollback;
    return (undef);
  };

  return (1);
}

sub fetch {
  my ($self, $fetch) = splice(@_, 0, 2);

  my $return;

  $fetch = _statementify($fetch) or do {
    warn, return (undef);
  };

  eval {
    $return = $self->{DBH}->selectall_arrayref(
      $self->{Statement}->$fetch,
      ref($_[0]) eq 'HASH'
        ? shift(@_)
        : undef,
      @_
    );
  };
  $@ and do {
    warn $@;
    return (undef);
  };

  return ($return);
}


sub store {
  my ($self, $store) = splice(@_, 0, 2);

  $store = _statementify($store) or do {
    warn, return (undef);
  };

  eval {
    my $sth = $self->{DBH}->prepare(
      $self->{Statement}->$store,
      ref($_[0]) eq 'HASH'
        ? shift(@_)
        : undef
    );
    $sth->execute_array(@_) or do {
      die;
    };
  };
  $@ or do {
    warn $@;
    $self->{DBH}->rollback;
    return (undef);
  };

  return (1);
}


__PACKAGE__;
