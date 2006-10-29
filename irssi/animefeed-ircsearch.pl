# deref.pl: A URL dereference module.

use strict;
use Text::ParseWords;
use DBI;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'animefeed-ircsearch',
           'description' => 'AnimeFeed database search tool',
           'license'     => 'GPL v2' );

my %COLOR;
my $num = 1;
map { $COLOR{$_} = "\x03" . $num++ } ( 'WHITE', 'BLACK', 'BLUE', 'GREEN'. 'RED', 'BROWN', 'PURPLE',
                                       'ORANGE', 'YELLOW', 'LIGHT_GREEN', 'TEAL', 'LIGHT_BLUE',
                                       'ROYAL_BLUE', 'PINK', 'DARK_GREY', 'LIGHT_GREY' );

Irssi::settings_add_str($IRSSI{'name'}, 'animefeed_channels', '');

my %active_chans;
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('animefeed_channels'));
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $active_chans{uc($to)}){
    if($message =~ /^\s*\@(find|torrent)\s+(.+)/i){
      # we target the sender, no matter where it was recieved from
      animefeed_search($server, $from, $to, $from, $address, $2);
    }
  }

  return 1;
}

sub animefeed_search {
  my ($server, $target, $to, $from, $address, $terms) = @_;
  my ($dbh, $sth);

  my $regex = '.*';
  map { $regex .= $_ . '.*' } split(/\s+/, $terms);
  if($regex =~ /^(\.\*)+$/){
    $server->command("msg $target $COLOR{PINK}Error: your query is very inspecific.");
    return;
  }
  eval {
    $dbh = DBI->connect("dbi:Pg:dbname=animefeed", undef, undef,
                        { RaiseError => 1,
                          PrintError => 0,
                          AutoCommit => 0 });
    $sth = $dbh->prepare("SELECT title,url,round(extract(epoch from age(current_timestamp, stamp))/86400) " .
                         "FROM items WHERE title ~* ? OR url ~* ? " .
                         "ORDER BY stamp DESC");
    $sth->execute($regex, $regex);

    if($sth->rows == 0){
      $server->command("notice $target $COLOR{PINK}BitTorrent search: no results.");
    } elsif($sth->rows > 0){
      $server->command("msg $target $COLOR{LIGHT_BLUE}" . $sth->rows .
                       " BitTorrent results for query `$terms' (/$regex/i):");
    }
    my $count = 0;
    while($sth->rows > 0 and defined (my $result = $sth->fetchrow_arrayref) and $count++ < 5){
      my $age = sprintf('%d da%s old', $result->[2], $result->[2] != 1 ? 'ys' : 'y');
      $server->command("msg $target $COLOR{LIGHT_BLUE}Title: [ $COLOR{ORANGE}$result->[0] $COLOR{LIGHT_BLUE}] " .
                       "Link: [ $COLOR{ORANGE}$result->[1] $COLOR{LIGHT_BLUE}] " . 
                       "Age: [$COLOR{ORANGE} $age $COLOR{LIGHT_BLUE}]");
    }
    if($sth->rows > 5){
      $server->command("msg $target $COLOR{PINK}More results found. Please be more specific.");
    }

    $sth->finish;
    $dbh->disconnect;
  };
  if($@){
    $sth->finish if defined $dbh;
    $dbh->disconnect if defined $dbh;
    $server->command("msg $target $COLOR{PINK}Error with the search engine: $@");
  }
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}