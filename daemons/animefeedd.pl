#!/usr/bin/env perl
#
# animefeedd.pl: animefeed daemon which aggregates rss feeds into a single database.
#
# Copyright (C) 2006   Tristan Willy <tristan.willy@gmail.com>
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

use warnings;
use strict;
use XML::Twig;
use LWP::Simple;
use URI::Escape;
use DBI;

# Configurable
my $update_interval = 30;
my %feeds = ( 'Tokyo Toshokan' => { 'url' => 'http://tokyotosho.com/rss.php' },
              'Baka Updates'   => { 'url' => 'http://www.baka-updates.com/rss.php' }
            );

my $twig = new XML::Twig(
  twig_handlers => { 'item' => \&process_item,
                     'ttl'  => \&process_ttl }
  );

# Core loop: Get the feeds, process them, and then sleep for the minimal TTL.
my ($dbh, $item_sth); # needs to be accessed by twig handlers
while(1) {
  ($dbh, $item_sth) = ();
  $dbh = DBI->connect("dbi:Pg:dbname=animefeed", undef, undef,
                      { RaiseError => 1,
                        PrintError => 0,
                        AutoCommit => 0 }) or
         do { $dbh = undef };
  eval {
    $item_sth = $dbh->prepare('INSERT INTO items VALUES (DEFAULT, ?, ?, \'now\')');

    # Get the feeds
    foreach my $feed_name (keys %feeds){
      my $ts = `date`;
      chomp $ts;
      print "$ts: Notice: Processing `$feed_name'.\n";
      eval {
        $twig->parse(get($feeds{$feed_name}{url}));
        $twig->purge;
      };
      if($@){
        warn "Error: Failed to process `$feed_name'.\n";
        $dbh->rollback;
      }
    }
    $item_sth->finish;
    $dbh->commit;
    $dbh->disconnect;
    my $secs_left = $update_interval * 60;
    do { $secs_left -= sleep($secs_left) } while($secs_left > 0);
  };
  if($@){
    warn "Database error: $@\n";
    sleep(60);
    next;
  }
}

# Called for each item in the RSS channel
sub process_item {
  my ($twig, $item) = @_;
  my ($title, $url);
  eval {
    $title = $item->first_child('title')->text;
    $url = uri_unescape($item->first_child('link')->text);
  };
  if($@){
    # No title or link. This probably isn't valid RSS 2.0 :/
    $twig->purge;
    return;
  }

  # Execute insert without complaining about errors.
  {
    local $item_sth->{RaiseError};
    $item_sth->execute($title, $url);
  }
  $dbh->commit;

  $twig->purge;
}

# RSS feed defines a TTL. Check if it is smaller than the current TTL.
sub process_ttl {
  my ($twig, $ttl) = @_;
  my $ttl_minutes = $ttl->text;
  if($ttl_minutes < $update_interval){
    $update_interval = $ttl_minutes;
    print "Notice: Set update interval to $update_interval minutes.\n";
  }
}

