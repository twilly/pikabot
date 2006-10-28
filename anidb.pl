# AniDB script for irssi

use strict;
use DBI;
use Text::ParseWords;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.10';
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
    if($message =~ /^[^!]*!anidb/i){
      if(trigger_anidb($server, $target, $to,
		       $from, $address, $message) == 0) {
	return 0; # Stop message processing if our trigger wants that.
      }
    }
  }
  return 1;
}

sub trigger_anidb {
  my ($server, $target, $to, $from, $address, $message) = @_;

  $message =~ s/\s+/ /g;
  $message =~ s/^\!\S+//;
  $message =~ s/^\s+//;
  $message =~ s/\s+$//;

  if($message =~ /^help\s*$/i or length($message) == 0){
    $server->command("msg $target \x0311`!anidb' usage: " .
		     "!anidb ID:<number> or !anidb <title>");
    return 1;
  }

  if($message =~ /ID:(\d+)/i){
    return trigger_anidb_query($1, $server, $target, $from, $message);
  } else {
    return trigger_anidb_search($server, $target, $from, $message);
  }
}

sub trigger_anidb_query {
  my ($aid, $server, $target, $from, $message, $no_recurse) = @_;

  my $dbh = DBI->connect("dbi:Pg:dbname=anidb",
			 undef, undef,
			 { RaiseError => 1, AutoCommit => 1 })
    or eval { warn "[ERROR] Error connecting to the database: $DBI::errstr\n"; return 1; };

  my ($type, $eps, $rating, $startdate, $enddate, $url);
  my @titles;
  my @genres;
  my $sth;
  # Try to get the general data from the DB
  eval {
    $sth = $dbh->prepare("SELECT type,numeps,rating,startdate,enddate,url " .
			 "FROM anime,cache_state WHERE anime.aid = $aid AND cache_state.aid = $aid " .
			 "AND age(last_refreshed) < interval '1m'");
    $sth->execute;
  };
  if(!$@){
    if($sth->rows > 0){ # Did we get a DB hit?
      ($type, $eps, $rating, $startdate, $enddate, $url) = $sth->fetchrow_array;
      eval { # Got a DB hit, gather other info.
	$sth = $dbh->prepare("SELECT title from titles where aid = $aid");
	$sth->execute;
	while (defined (my $rowref = $sth->fetchrow_arrayref)) {
	  push @titles, $rowref->[0];
	}
	$sth = $dbh->prepare("SELECT gname FROM genre, genre_names WHERE genre.aid = $aid and genre.gid = genre_names.gid");
	$sth->execute;
	while (defined (my $rowref = $sth->fetchrow_arrayref)) {
	  push @genres, $rowref->[0];
	}
      };
      if(!$@){
	my $msg; # No DB error. We have all the info we need.
	my $genres = " Genre: [ @genres ]";
	my $url = defined $url ? " URL: [ $url ]" : '';
	my $oldlen = 0;
	my $title_str;
	foreach my $title (@titles){
	  $title_str .= "<$title> ";
	}
	chop $title_str;
	my $numeps = defined $eps ? "#Eps: [ $eps ] " : '';
	my $rating_str = defined $rating ? "Rating: [ $rating ]" : '';
	do {
	  $oldlen = defined $msg ? length $msg : 0;
	  $, = ', ';
	  $msg = "\x0305{ID:$aid}\x0313 $title_str\x0311 $genres $numeps $rating_str $url AniDB: [ \x0312http://anidb.info/a$aid\x0311 ]";
	  $msg =~ s/ +/ /g; # Remove any extra spaces
	  if($#titles > 0) { pop @titles }
	  $genres = '';
	  $url = '';
	} while(length $msg > 500 && $oldlen != length $msg);
	$server->command("msg $target $msg");
	$sth->finish;
	$dbh->disconnect;
	return 1;
      }
    } else {
      # No DB error but there's no data. Gather it first.
      $sth->finish;
      $dbh->disconnect;
      Irssi::print "[DEBUG] AniDB Script: Miss on $aid.";
      `$path/anidb_query.pl $aid`;
      #sleep(1);
      if(not defined $no_recurse){
	return trigger_anidb_query($aid, $server, $target, $from, $message, 1);
      } else {
	$server->command("msg $target General AniDB query error for ID:$aid. Please try again.");
	return 1;
      }
    }
  }

  warn $@;
  $server->command("msg $target Oops: $@");
  $sth->finish;
  $dbh->disconnect;
  return 1;
}

sub trigger_anidb_search {
  my ($server, $target, $from, $message, $no_recurse) = @_;

  # TODO: Local searching
  my %results;
  open(QUERY, "$path/anidb_search.pl \"$message\" |")
    or eval {
      warn "Error: Unable to execute anidb search script: $!\n"; return 1;
    };
  while(<QUERY>){
    if(/<aid (\d+)>([^<]+)<\/aid>/){
      push @{$results{$1}}, $2;
    }
  }
  close(QUERY);

  if(scalar keys %results == 0){
    $server->command("msg $target AniDB: No Results");
    return 1;
  }

  if(scalar keys %results > 10){
    $server->command("msg $target AniDB: Too many hits. " .
		     "Please be more specific.");
    return 1;
  }

  # Generate the messages
  my @tsets;
  my @aids = sort { $a <=> $b } keys %results;
  if($#aids > 0){
    foreach my $key (@aids) {
      my $ic = 0;
      my $tmsg = "ID:$key [ ";
      foreach my $title (@{$results{$key}}) {
	if ($ic != 0) {
	  $tmsg .= ", ";
	}
	if ($ic > 2) {
	  $tmsg .= "..."; last;
	}
	$tmsg .= "\x0312$title\x0311";
	$ic++;
      }
      $tmsg .= " ]";
      push @tsets, $tmsg;
    }

    my @msets;
    my $msg = "\x0313AniDB Title Results:\x0311 ";
    my $c = 0;
    foreach my $tmsg (@tsets) {
      if (length($msg) + length($tmsg) + 2 > 400) {
	push @msets, $msg;
	$msg = "\x0313AniDB Title Results:\x0311 ";
	$c = 0;
      }
      if ($c++) {
	$msg .= " ";
      }
      $msg .= $tmsg;
    }
    push @msets, $msg;

    foreach $msg (@msets) {
      $server->command("msg $target $msg");
    }
  }
  # One hit, lets automatically retrive that anime.
  my ($aid) = $aids[0];
  return trigger_anidb_query($aid, $server, $target, $from, $message);
}

sub trigger_anidb_search_local {
  my ($resultsref, $socket, $reply_to, $from, $message) = @_;

  # Kill any strange characters
  $message =~ s/[^a-zA-Z0-9 ]//g;

  if($message =~ /no cache\s*$/i or length($message) == 0){
    warn "[DEBUG] AniDB: local search execute but is bypassed or has a blank message.\n";
    return 0;
  }

  my $dbh = DBI->connect("dbi:Pg:dbname=anidb",
			 'anidb', 'pikachu',
			 { RaiseError => 1, AutoCommit => 1 })
    or eval { warn "[ERROR] Error connecting to the database: $DBI::errstr\n"; return 1; };

  my $regex = $message;
  $regex =~ s/ /\.\+/g; # Transform query into SQL regex
  $regex = '.*' . $regex . '.*';

  warn "[DEBUG] AniDB SQL Query with $message: SELECT * FROM titles WHERE title ~* '$regex'\n";
  my $sth = $dbh->prepare("SELECT * FROM titles WHERE title ~* '$regex'") or return 0;
  my $retcode = 0;
  eval {
    $sth->execute;
    while (defined (my $rowref = $sth->fetchrow_arrayref)) {
      push @{$resultsref->{$rowref->[0]}}, $rowref->[1];
    }
  };
  if($@){
    warn "[ERROR] AniDB: Failure to execute a quick search: $@\n";
  } else {
    if($sth->rows > 0){
      $retcode = 1;
    } else {
      warn "[DEBUG] AniDB: Local search completed but there are no results.\n";
    }
  }
  $sth->finish;
  $dbh->disconnect;
  return $retcode;
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
