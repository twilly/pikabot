#!/usr/bin/env perl
# animefeedd.pl: animefeed daemon which aggregates rss feeds into a single database.
#
# Copyright (C) 2006   Tristan Willy <tristan.willy at gmail.com>
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

use File::Basename;
my $script = basename($0);

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
  eval {
    # Get the feeds
    $dbh = undef;
    foreach my $feed_name (keys %feeds){
      $dbh = connect_database() if not defined $dbh;
      if(not defined $dbh){
        warn "$script: Error: failed to connect to database.\n";
        next;
      }
      my $ts = `date`;
      chomp $ts;
      print "$ts: $script: Notice: Processing `$feed_name'.\n";
      eval {
        $twig->parse(get($feeds{$feed_name}{url}));
        $twig->purge;
      };
      if($@){
        warn "$script: Error: Failed to process `$feed_name': $@\n";
        $dbh->rollback;
        # force a reconnect
        $dbh->disconnect;
        $dbh = undef;
      }
    }
    $item_sth->finish;
    $dbh->commit;
    $dbh->disconnect;
    my $secs_left = $update_interval * 60;
    do { $secs_left -= sleep($secs_left) } while($secs_left > 0);
  };
  if($@){
    warn "$script: Database error: $@\n";
    sleep(60);
    next;
  }
}

sub connect_database {
 my $dbh;
 $dbh = DBI->connect("dbi:Pg:dbname=pikabot", undef, undef,
                    { RaiseError => 1,
                      PrintError => 0,
                      AutoCommit => 0 }) or return undef;
 eval {
  $dbh->do("SET search_path TO animefeed");
  $item_sth = $dbh->prepare('INSERT INTO items VALUES (DEFAULT, ?, ?, \'now\')');
 };
 if($@){
  $dbh->disconnect;
  return undef;
 }
 return $dbh;
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

  # See if it's in the database and short-circut so we won't complain
  # later about a failed but dont-care DB insertion.
  my $preitem_sth = $dbh->prepare("SELECT * FROM items WHERE url = ?");
  my $nrows = $preitem_sth->execute($url);
  if($nrows == 0){
    # Execute insert without a complete abort
    {
      local $item_sth->{RaiseError};
      $item_sth->execute($title, $url)
        or do {
          warn "$script: Warning: database failed to insert \"$title\" with url \"$url\".\n";
        };
    }
    $dbh->commit;
  }

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
