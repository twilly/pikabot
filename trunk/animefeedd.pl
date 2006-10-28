#!/usr/bin/perl -w

# Scrape data from RSS feeds and load them into the database.

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
  $dbh = DBI->connect("dbi:Pg:dbname=animefeed;host=supersrv.internal", 'animefeed', 'theanime',
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

