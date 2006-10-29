# AniDB script for irssi

use strict;
use DBI;
use Text::ParseWords;
use anidb;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.11';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'AniDB',
           'description' => 'AniDB in-channel query & report.',
           'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'anidb_channels', '');
Irssi::settings_add_str($IRSSI{'name'}, 'anidb_path', '');

my (%anidb_active_chans, $path);
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $anidb_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('anidb_channels'));
  $path = Irssi::settings_get_str('anidb_path');
  if(not -d $path){
    Irssi::print("Warning: anidb_path ($path) is not a directory.");
  }
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $anidb_active_chans{uc($to)}){
    if($message =~ /^[^!]*!anidb\s+(.+)/i){
      trigger_anidb($server, $target, $to, $from, $address, $1);
    }
  }

  return 1;
}

sub trigger_anidb {
  my ($server, $target, $to, $from, $address, $query) = @_;

  my $anidb = new anidb('Database' => 'anidb-nextgen')
    or do {
      $server->command("msg $target \x0311AniDB: Error pulling up anidb module.");
      return;
    };

  # compress spaces
  $query =~ s/\s+/ /g;
  $query =~ s/^\s+//;
  $query =~ s/\s+$//;

  if($query =~ /^help\s*$/i or length($query) == 0){
    $server->command("msg $target \x0311`!anidb' usage: " .
                     "!anidb ID:<number> or !anidb <title>");
    return 1;
  }

  # If the query matches a number or specific ID, then run against that.
  # If not, then the user is searching with a title rather than an ID.
  my $anime;
  if($query =~ /^(ID:)?(\d+)/i){
    $anime = $anidb->anime_query($2);
  } else {
    Irssi::print("anidb: running query `$query'.");
    my @titles = $anidb->title_query($query);
 
    # Check if there are any or too many results
    if($#titles < 0){
      $server->command("msg $target AniDB: No Results");
      $anidb->close();
      return;
    }
    if($#titles > 10){
      $server->command("msg $target AniDB: Too many hits. Please be more specific.");
      $anidb->close();
      return;
    }

    # More than one result means we should print out all the title maches
    # This will also break up results into multiple messages should a few
    # titles exceed the maximum message length limit.
    if($#titles > 0){
      my $header = "\x0313AniDB Title Results:\x0311 ";
      my $msgbuff = $header;
      foreach my $title (@titles){
        my $prevstate = $msgbuff;
        my $item;
        $item = ' ' if $msgbuff ne $header;
        $item .= "ID:$title->{id} [\x0312 $title->{title}\x0311 ]";
        if(length($msgbuff . $item) > 512){
          $server->command("msg $target $prevstate");
          $msgbuff = $header . $item;
        } else {
          $msgbuff .= $item;
        }
      }
      $server->command("msg $target $msgbuff");
    }

    # run against the first title match
    if(not defined $titles[0]->{id}){
      Irssi::print "$IRSSI{name}: Error: anidb->title_query seems to be ok, but we got a undefined aid.";
      $anidb->close();
      return;
    } else {
      $anime = $anidb->anime_query($titles[0]->{id});
    }
  }

  if(not defined $anime){
    Irssi::print "$IRSSI{name}: anidb->anime_query returned a undefined result.";
    $server->command("msg $target AniDB: Internal error. Try again at a later time.");
    $anidb->close();
    return;
  }

  # Print out requested anime info
  my $msgbuff .= "\x0305{ID:$anime->{aid}}\x0313 ";
  foreach my $title (@{$anime->{titles}}){
    $msgbuff .= "<$title> ";
  }
  $msgbuff .= "\x0311";
  $msgbuff .= "Genre: [ @{$anime->{genres}} ] " if $#{$anime->{genres}} >= 0;
  $msgbuff .= "#Eps: [ $anime->{numeps} ] " if defined $anime->{numeps};
  $msgbuff .= "Rating: [ $anime->{rating} ] " if defined $anime->{rating};
  $msgbuff .= "URL: [ $anime->{url} ] " if defined $anime->{url};
  $msgbuff .= "AniDB: [ \x0312http://anidb.info/a$anime->{aid}\x0311 ]";
  $server->command("msg $target $msgbuff");

  $anidb->close();
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
