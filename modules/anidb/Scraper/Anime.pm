#!/usr/bin/perl -w
package anidb::Scraper::Anime;
# anidb::Scraper::Anime.pm:
#   Get that crap outta my name space!
#
# Copyright (C) 2009  Tristan Willy  <tristan.willy at gmail.com>
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

use HTML::Scrape qw(put);


sub basic_put($) {
  my ($e) = splice(@_); # safety first~

  return (
    sub {
      if ($_[1] =~ /^[aA](\d+)$/) {
        $_[1] = $1;
      } else {
        $_[1] =~ s/\s*\($//;
      }

      $_[0]->{'element'}->{$e} = $_[1];
    }
  );
}

sub title_put($) {
  my ($e) = splice(@_); # safety first!

  return (
    sub {
      if ($_[1] =~ /\byes/i) {
        $_[0]->{'element'}->{$e} = 1;
      } else {
        $_[0]->{'element'}->{$e} = 0;
      }
    }
  );
}

sub synonyms_put($) {
  my ($e) = splice(@_); # safety is important! :D

  return (
    sub {
      $_[0]->{'element'}->{$e} = [ split(/\s*,\s*/, $_[1]) ];
    }
  );
}

sub date_put($) {
  my ($e) = splice(@_); # safeeety~~~~

  return (
    sub {
      $_[1] =~ m{
        ^\s* # clean up~

        (\d{1,2}) # day (1)
          \.
        (\d{1,2}) # month (2)
          \.
        (\d{4}) # year (3)

        (?:
          \s+till\s+ # is it ongoing or finished?
          (?:
            (\?) # unknown end (4)
              |
            (\d{1,2}) # day (5)
              \.
            (\d{1,2}) # month (6)
              \.
            (\d{4}) # year (7)
          )
        )?
      }x and do {
        my @dates = map {
          s/^0+//; $_
        } grep {
          defined
        } @{[ $3, $2, $1, $7, $6, $5 ]};

        $_[0]->{'element'}->{$e->[0]} = sprintf('%04d-%02d-%02d', @dates[0..2]);

        if (defined($4)) {
          $_[0]->{'element'}->{$e->[1]} = '?';
        } elsif (@dates == 6) {
          $_[0]->{'element'}->{$e->[1]} = sprintf('%04d-%02d-%02d', @dates[3..5]);
        }
      };
    }
  );
}

sub type_put($) {
  my ($e) = splice(@_); # D:

  return (
    sub {
      $_[1] =~ m{
        ^\s* # clean up~

        ([^,]+) # type~

        (?:
          \s*,\s* # it's got an ep count
          (?:
            (unknown.*of) # conan style ep count
              |
            (\d+) # normal ep count
          )
          \s*episodes?
        )?
      }x and do {
        $_[0]->{'element'}->{$e->[0]} = $1;

        if (defined($2)) {
          $_[0]->{'element'}->{$e->[1]} = '?';
        } elsif (defined($3)) {
          $_[0]->{'element'}->{$e->[1]} = $3;
        }
      };
    }
  );
}

sub fail_put($) {
  my ($e) = splice(@_); # safety first!

  return (
    sub {
      if ($_[1] =~ /no results/i) {
        $_[0]->{'element'}->{$e} = 'No matches found';
      } elsif ($_[1] =~ /hentai/i) {
        $_[0]->{'element'}->{$e} = 'Anime has been flagged as adult content';
      } else {
        die "Could not find failure in message:\n$_[1]";
      }
    }
  );
}

sub regex_put($$) {
  my ($e, $r) = splice(@_); # safety first~

  return (
    sub {
      ($_[1] =~ $r and
        defined($1)) or do {

        die "Could not find $e matching '$r' in item: $_[1]";
      };

      $_[0]->{'element'}->{$e} = $1;
    }
  );
}

sub basic_machine($$;$$) {
  my ($l, $f, $d, $r) = @_;

  defined($r) or do {
    lc([caller(1)]->[3]) =~ /([^\:]+)$/ or do {
      die;
    };

    $r = $1;
  };
  ref($d) eq 'CODE' or do {
    $d = undef;
  };

  return (
    [
      # Find required section
      { 'tag'     => 'div',
        'require' => { 'id' => qr/$l/ } },
      { 'tag'     => 'tr',
        'require' => { 'class' => qr/$r/ } },
      { 'tag'     => 'td',
        'require' => { 'class' => qr/value/ } },

      # Save the item
      { 'text'    => $d ? $d->($f) : put($f) },
    ]
  );
}


# Enter the machines~

sub SYNONYMS() {
  basic_machine('tab_2_pane', 'title', \&synonyms_put)
}

sub SHORTNAMES() {
  basic_machine('tab_2_pane', 'title')
}

sub RATING() {
  basic_machine('tab_1_pane', 'value', undef, '(?<!tmp)rating')
}

sub TMPRATING() {
  basic_machine('tab_1_pane', 'value')
}

sub TYPE() {
  basic_machine('tab_1_pane', [qw(type value)], \&type_put)
}

sub YEAR() {
  basic_machine('tab_1_pane', [qw(from to)], \&date_put)
}

sub SEARCH() {
  [
    # Find required section
    { 'tag'     => 'table',
      'require' => { 'class' => qr/animelist/ } },

    # Grab a single result
    { 'label'   => 'result',
      'tag'     => 'td',
      'require' => { 'class' => qr/name/ } },

    # Grab link
    { 'tag'     => 'a',
      'attr'    => { 'href' => regex_put('id', qr/aid=(\d+)/) } },

    # Grab "term" (title)
    { 'text'    => put('title') },

    # Commit and loop back
    { 'tag'    => 'tr',
      'commit' => 1,
      'goto'   => 'result' },
  ]
}

sub BASIC() {
  [
    # Find required section
    { 'tag'     => 'div',
      'require' => { 'id' => qr/tab_2_pane/ } },
    { 'tag'     => 'tr',
      'require' => { 'class' => qr/romaji/ } },
    { 'tag'     => 'td',
      'require' => { 'class' => qr/value/ } },

    # Save the title
    { 'text'    => basic_put('title') },

    # Save the link
    { 'tag'     => 'a',
      'require' => { 'class' => qr/short_link/ },
      'attr'    => { 'href' => put('link') } },

    # save the text
    { 'text'    => basic_put('id') },
  ]
}

# This is an example of a scraper that can
# fail, not all animes have this crap.  Instead
# of making it *try* to find them, I'm gonna
# code it to work or fail.  The driver can
# deal with it from that point on (for now).
sub TITLES() {
  [
    # Pop down to the right section
    { 'tag'     => 'div',
      'require' => { 'id' => qr/tab_2_pane/ } },

    # Start parsing~ _otitle_put() sets the verified flag
    { 'tag'     => 'tr',
      'label'   => 'loop',
      'require' => { 'class' => qr/official verified/ },
      'attr'    => { 'class' => title_put('state') } },

    # Store language
    { 'tag'     => 'span',
      'require' => { 'title' => qr/language/ } },
    { 'tag'     => 'span' },
    { 'text'    => put('type') },

    # Store that language's title, commit and loop back
    { 'tag'     => 'label' },
    { 'text'    => put('title'),
      'goto'    => 'loop',
      'commit'  => 1 },
  ]
}

sub CATEGORIES() {
  [
    # Find the required section
    { 'tag'     => 'div',
      'require' => { 'id' => qr/tab_1_pane/ } },
    { 'tag'     => 'tr',
      'require' => { 'class' => qr/categories/ } },
    { 'tag'     => 'td',
      'require' => { 'class' => qr/value/ } },

    [
      # Grab the id then drop! :D
      { 'label'   => 'catears',
        'tag'     => 'a',
        'attr'    => { 'href' => regex_put('id', qr/catid\.(\d+)/) } },

      # We're all done, halt
      { 'tag'   => 'tr',
        'goto'  => 'cattail' },
    ],

    # Save category title
    { 'text'    => put('title'),
      'goto'    => 'catears',
      'commit'  => 1 },

    # Halt state
    { 'label' => 'cattail',
      'goto'  => 'cattail' }
  ]
}

sub PRODUCERS() {
  [
    # Find the required section
    { 'tag'     => 'div',
      'require' => { 'id' => qr/tab_1_pane/ } },
    { 'tag'     => 'tr',
      'require' => { 'class' => qr/producers/ } },
    { 'tag'     => 'td',
      'require' => { 'class' => qr/value/ } },

    [
      # Grab the url and drop down~
      { 'label' => 'loop',
        'tag'   => 'a',
        'attr'  => {
          'title' => regex_put('type', qr/^(\S+)/),
          'href'  => regex_put('id', qr/creatorid=(\d+)/) } },

      # We're all done, halt
      { 'tag'   => 'tr',
        'goto'  => 'halt' },
    ],

    # Commit the name and link, then loop back
    { 'text'    => put('title'),
      'goto'    => 'loop',
      'commit'  => 1 },

    # halt state
    { 'label' => 'halt',
      'goto'  => 'halt' }
  ]
}

# Note that the old method of simply grabbing
# the first link and calling it "official" is
# a BAAAAAAAD idea. :)
sub RESOURCES() {
  [
    # Find the required section
    { 'tag'     => 'div',
      'require' => { 'id' => qr/tab_1_pane/ } },
    { 'tag'     => 'tr',
      'require' => { 'class' => qr/resources/ } },
    { 'tag'     => 'td',
      'require' => { 'class' => qr/value/ } },

    [
      # Set label, store link, drop
      { 'label' => 'loop',
        'tag'   => 'a',
        'attr'  => { 'href' => put('link') } },

      # We're at the bottom
      { 'tag'   => 'tr',
        'goto'  => 'halt' },
    ],

    # Commit the name and link, then loop back
    { 'text'    => put('title'),
      'goto'    => 'loop',
      'commit'  => 1 },

    # Halt state
    { 'label' => 'halt',
      'goto'  => 'halt' },
  ]
}

sub FAILURE() {
  [
    { 'tag'     => 'div',
      'require' => { 'class' => qr/g_msg (?:note|warning)/ } },
    { 'tag'     => 'p' },
    { 'text'    => fail_put('failure') }
  ]
}


__PACKAGE__;
