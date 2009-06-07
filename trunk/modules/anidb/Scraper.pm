#!/usr/bin/perl -w
package anidb::Scraper;
# anidb::Scraper.pm:
#   Screen scraper for AniDB.net...
#
# Copyright (C) 2006-2009  Tristan Willy  <tristan.willy at gmail.com>
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

use LWP::UserAgent;
use Compress::Zlib;
use Encode;
use HTML::Scrape;

sub new { shift->spawn(@_) }

sub spawn {
  my ($class, $config, $header, $type) = @_;

  (defined($type) and
    length($type)) or do {

    warn, return (undef);
  };
  ref($header) eq 'HASH' or do {
    return (undef);
  };
  (ref($config) eq 'HASH' and
    defined($config->{agent}) and
      defined($config->{timeout})) or do {

    warn, return (undef);
  };

  $type = join('::', __PACKAGE__, "\u$type");

  eval qq{
    require $type;
  };
  $@ and do {
    warn, return (undef);
  };

  my $lwp = LWP::UserAgent->new or do {
    warn, return (undef);
  };

  foreach my $method (keys(%{$config})) {
    eval sprintf(
      q{
        $lwp->%s($config->{$method});
      },
      $method
    );
    $@ and do {
      warn $@;

      warn, return (undef);
    };
  }

  return (
    bless (
      {
        LWP => $lwp,
        Header => $header,
        Current => undef,
        Machine => $type
      },
      $class
    )
  );
}

sub get { shift->download(@_) }

sub download {
  my ($self, $url) = @_;

  my $request = HTTP::Request->new(GET => $url) or do {
    warn, return (undef);
  };
  foreach my $k (keys(%{$self->{Header}})) {
    $request->header($k => $self->{Header}->{$k});
  }

  $self->{Current} = $self->{LWP}->request($request);

  $self->{Current}->is_success or do {
    $self->reset;
    warn, return (undef);
  };

  return (1);
}

sub content {
  my ($self) = @_;

  defined($self->{Current}) or do {
    warn, return (undef);
  };

  defined($self->{Current}->content_encoding) and do {
    $self->{Current}->content_encoding eq 'gzip' and do {
      return (
        decode(
          'utf8',
          Compress::Zlib::memGunzip($self->{Current}->content)
        )
      );
    };

    warn($self->{Current}->content_encoding), return (undef);
  };

  return (
    decode(
      'utf8',
      $self->{Current}->content
    )
  );
}

sub reset {
  my ($self) = @_;

  defined($self->{Current}) and do {
    $self->{Current} = undef;
  };
}

sub fetch {
  my ($self, $fetch) = @_;

  defined($fetch) or do {
    warn, return ();
  };

  $fetch = uc($fetch);

  eval {
    ref($self->{Machine}->$fetch) eq 'ARRAY' or do {
      die;
    };
  };
  $@ and do {
    warn, return ();
  };

  my $s = HTML::Scrape->new(Machine => $self->{Machine}->$fetch) or do {
    warn, return ();
  };
  my @r = $s->scrape($self->content) or do {
    warn, return ();
  };

  @r or do {
    warn, return ();
  };

  return (@r);
}



__PACKAGE__;
