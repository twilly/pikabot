package anidb;

use strict;
use LWP::UserAgent;
use Compress::Zlib;
use DBI;
use Encode;
use HTML::TreeBuilder;
use HTML::Entities;
use URI::Escape;

sub new {
  my $type = shift;
  my %params = @_;
  my $self = {};

  # required information
  if(not defined $params{Database}){
    return undef;
  }

  # set optional paramaters
  map {
    $params{$_} = exists $params{$_} ?  $params{$_} : undef;
  } ('Username', 'Password', 'Server');

  # connect to the DB
  my $connect_str = "dbi:Pg:dbname=$params{Database}";
  $connect_str .= ";host=$params{Server}" if defined $params{Server};
  $self->{dbh} =
    DBI->connect($connect_str,
                 $params{Username}, $params{Password},
                 { RaiseError => 1, AutoCommit => 0 })
      or return undef;

  # make a LWP object for quering anidb
  my $ua = LWP::UserAgent->new() or return undef;
  $ua->timeout(15);
  $ua->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.7.12) ' .
             'Gecko/20050922 Fedora/1.0.7-1.1.fc3 Firefox/1.0.7');
  $self->{ua} = $ua;

  return bless $self, $type;
}

sub DESTORY {
  my $self = shift;
  $self->{dbh}->disconnect if defined $self->{dbh};
}

# public title_query(<search string>)
# Searches local DB for title hits and queries anidb if a miss occurs.
# Returns: array of hashes where hash contains ID and title
sub title_query {
  my ($self, $query) = @_;
  my $titles;

  $query = strip($query);

  $titles = title_search($self, $query);
  if(not defined $titles){
    $titles = anidb_search($self, $query);
    if(defined $titles){
      title_insert($self, $query, $titles);
    }
  }

  if(defined $titles){
    return @{$titles};
  } else {
    return undef;
  }
}


# public anime_query(<id>)
# searches the local DB for anime ID hits and queries anidb if a miss occurs
sub anime_query {
  my ($self, $id) = @_;
  my $info;

  $info = anime_search($self, $id);
  if(not defined $info){
    $info = anidb_anime($self, $id);
    if(defined $info){
      anime_insert($self, $info);
    }
  }

  return $info;
}

# queries the local database for titles
sub title_search {
  my ($self, $query) = @_;
  my @results;

  eval {
    # select title results if we can match a query
    my $sth = $self->{dbh}->prepare
      ("SELECT id_num, title FROM search_cache, search_hits " .
       "WHERE search_cache.sid = search_hits.sid " .
       "AND terms = ?");
    $sth->execute($query);
    while(my $row = $sth->fetchrow_arrayref()){
      push @results,
        { 'id' => $row->[0],
          'title' => $row->[1] };
    }
    $sth->finish();
  };
  if($@){
    warn "anidb.pm: Database error: $@\n";
    return undef;
  }

  # return results if any
  if($#results >= 0){
    return \@results;
  } else {
    return undef;
  }
}

# search the local database, return info hash on hit
sub anime_search {
  my ($self, $id) = @_;
  my %info =
    ('aid' => $id,
     'key descriptions' =>
      { 'titles' => 'titles [array ref]',
        'genres' => 'genre names [array ref]',
        'rating' => 'rating [scalar, float]',
        'type'   => 'type (ex: Movie, OVA, TV, etc) [scalar, string]',
        'numeps' => 'number of episodes [scalar, integer]',
        'url'    => 'url of official website [scalar, string]',
        'startdate' => 'first aired/released date [scalar, string, YYYY-MM-DD format]',
        'enddate' => 'last aired/released date [scalar, string, YYYY-MM-DD format]',
        'aid'    => 'AniDB anime id [scalar, integer]'
        }
    );

  # validity check
  if(not defined $id){
    warn "anidb.pm: stupid programmer alert";
    return undef;
  }
  if($id !~ /^\d+$/){
    warn "anidb.pm: anime_search: $id is not a number\n";
    return undef;
  }

  # can we find it?
  my @table_metadata = ( 'aid', 'type', 'numeps', 'rating',
                         'startdate', 'enddate', 'url' );
  eval {
    my $sth;
    $sth = $self->{dbh}->prepare
      ("SELECT * FROM anime WHERE aid = ?");
    $sth->execute($id);
    die "DB anime miss" if $sth->rows != 1;
    # put the row data into the info hash
    map {
      $info{shift @table_metadata} = $_;
    } $sth->fetchrow_array();
    $sth->finish();
  };
  if($@){
    return undef; # not found
  }

  eval {
    my $sth;
    # grab genres
    $sth = $self->{dbh}->prepare
      ("SELECT gname FROM genre, genre_names " .
       "WHERE genre_names.gid = genre.gid " .
       "AND genre.aid = ?");
    $sth->execute($info{aid});
    while(my @row = $sth->fetchrow_array()){
      push @{$info{genres}}, $row[0];
    }
    $sth->finish();

    # grab titles
    $sth = $self->{dbh}->prepare
      ("SELECT title FROM titles WHERE aid = ?");
    $sth->execute($info{aid});
    while(my @row = $sth->fetchrow_array()){
      push @{$info{titles}}, $row[0];
    }
    $sth->finish();
  };
  if($@){
    warn "anidb.pm: error: $@\n";
    return undef;
  }

  return \%info;
}

# inserts titles into the local database
sub title_insert {
  my ($self, $query, $titles) = @_;

  eval {
    my $sth;

    # insert search term
    $sth = $self->{dbh}->prepare
      ("INSERT INTO search_cache_table VALUES (DEFAULT, ?, 'now')");
    $sth->execute($query);
    $sth->finish();
    $self->{dbh}->commit(); # make the sid avialable

    # retrieve search term's sid
    $sth = $self->{dbh}->prepare
      ("SELECT sid FROM search_cache WHERE terms = ?");
    $sth->execute($query);
    die "Failed to retrieve search ID" if $sth->rows != 1;
    my $sid = $sth->fetchrow_arrayref()->[0];
    $sth->finish();

    # insert title results
    $sth = $self->{dbh}->prepare
      ("INSERT INTO search_hits VALUES (?, ?, ?)");
    foreach my $title (@{$titles}){
      $sth->execute($sid, $title->{id}, $title->{title});
    }
    $sth->finish();

    # commit transaction
    $self->{dbh}->commit();
  };
  if($@){
    warn "anidb.pm: database error: $@\n";
    $self->{dbh}->rollback();
  }
}

sub download_and_parse {
  my ($self, $url, $parser) = @_;

  # prepare a request
  my $request = HTTP::Request->new(GET => $url);
  $request->header('Referer' => 'http://www.anidb.info/perl-bin/');

  # download the page
  my $page = $self->{ua}->request($request);
  if($page->is_success){
    if(defined $page->content_encoding and
       $page->content_encoding eq 'gzip'){
      return $parser->($self,
                       decode('utf8', Compress::Zlib::memGunzip($page->content)));
    } else {
      return $parser->($self, decode('utf8', $page->content));
    }
  } else {
    warn "anidb.pm: error downling anidb page: " . $page->status_line() . "\n";
  }

  return undef;
}

# runs a anime query off anidb
sub anidb_anime {
  my ($self, $id) = @_;

  my $info =
    download_and_parse
      ($self,
       "http://www.anidb.info/perl-bin/animedb.pl?show=anime&aid=$id",
       \&anidb_anime_parse);
  $info->{aid} = $id;
  return $info;
}

# Runs a search off anidb
sub anidb_search {
  my ($self, $query) = @_;

  $query = uri_escape($query); # support for kanji
  return download_and_parse
    ($self,
     "http://www.anidb.info/perl-bin/animedb.pl?show=animelist&adb.search=" .
     $query . "&do.search.x=0&do.search.y=0", \&anidb_search_parse);
}

# parses anidb search HTML
# note: anidb will return the anime title page if there is only one hit
#       this should deal with that case to reduce load
sub anidb_search_parse {
  my ($self, $content) = @_;
  my $tree = HTML::TreeBuilder->new_from_content($content);
  my @titles;

  my $single_hit = $tree->look_down
    ('_tag', 'h1',
     sub { return 1 if ($_[0]->content_array_ref->[0] =~ /^Show Anime/); return 0 });
  if(defined $single_hit){
    # Single hit. Return the result.
    my ($aid, $title) = (0, '[none]');
    if($single_hit->content_array_ref->[0] =~ /^Show Anime - (.+)/){
      $title = $1;
    }
    my $link;
    if(defined ($link = $tree->look_down('_tag', 'a', \&test_aid_link)) and
       $link->attr('href') =~ /aid=(\d+)/){
      $aid = $1
    }

    # We have the actual page, push it to the local db
    anime_insert($self, anidb_anime_parse($self, $content));

    push @titles, { 'id' => $aid, 'title' => $title };
  } else {
    # Multiple hits. Lets walk down the table.
    my @hits = $tree->look_down('_tag', 'tr', \&test_tr);
    foreach my $hit (@hits){
      # Get the AID from the title link
      my $link = $hit->look_down('_tag', 'a', \&test_aid_link);
      my $aid = 0;
      if($link->attr('href') =~ /aid=(\d+)/){ $aid = $1 }

      # Titles are either there or in a italic subtag
      my $title = '';
      if(my $t = $link->look_down('_tag', 'i')){ # Non-Japanese title
        $title = decode_entities($t->content_array_ref->[0]);
      } else { # Japanese title
        $title = decode_entities($link->content_array_ref->[0]);
      }

      push @titles, { 'id' => $aid, 'title' => $title };
    }
  }
  $tree->delete;

  if($#titles >= 0){
    return \@titles;
  } else {
    return undef;
  }
}

sub test_tr {
  my $title_link = $_[0]->look_down('_tag', 'a') or return 0;
  return test_aid_link($title_link);
}

sub test_aid_link {
  my $tmp;
  if(defined ($tmp = $_[0]->attr('href')) and $tmp =~ /aid=/){
    return 1;
  }
  return 0;
}

sub match_two_row {
  my @list = @{$_[0]->content_array_ref()};
  if(scalar @list == 2 and
     $list[0]->tag() eq 'td' and
     $list[1]->tag() eq 'td'){
    return 1;
  }
  return 0;
}

# inserts an anidb anime page into the local database
# typical usage: anime_insert($self, anidb_anime_parse(HTML))
sub anime_insert {
  my ($self, $info) = @_;
  return undef if not defined $info;

  if(not exists $info->{aid} or
     not exists $info->{titles}){
    return undef; # not enough info scrapped
  }

  # put in any genres that may be needed
  anime_insert_genres($self, $info->{genres});

  # put in the title
  eval {
    my $sth;

    # put in basic anime info
    $sth = $self->{dbh}->prepare("INSERT INTO anime VALUES (?,?,?,?,?,?,?)");
    $sth->execute($info->{aid}, $info->{type}, $info->{numeps}, $info->{rating},
                  $info->{startdate}, $info->{enddate}, $info->{url});
    $sth->finish();

    # Genre association
    $sth = $self->{dbh}->prepare
      ("INSERT INTO genre VALUES ($info->{aid}, " .
       "(SELECT gid from genre_names where gname = ?))");
    foreach my $genre (@{$info->{genres}}){
      $sth->execute($genre);
    }
    $sth->finish();

    # Title association
    $sth = $self->{dbh}->prepare("INSERT INTO titles VALUES (?,?)");
    foreach my $title (@{$info->{titles}}){
      $sth->execute($info->{aid}, $title);
    }
    $sth->finish();

    # update cache status
    $sth = $self->{dbh}->prepare("INSERT INTO details_cache VALUES (?, 'now')");
    $sth->execute($info->{aid});
    $sth->finish();

    $self->{dbh}->commit();
  };
  if($@){
    warn "anidb.pm: error: $@\n";
    $self->{dbh}->rollback();
  }
}

# insert genres from a array ref
sub anime_insert_genres {
  my ($self, $genres) = @_;

  eval {
    my ($sth_select, $sth_insert);
    $sth_select = $self->{dbh}->prepare("SELECT * FROM genre_names WHERE gname = ?");
    $sth_insert = $self->{dbh}->prepare("INSERT INTO genre_names VALUES (DEFAULT, ?)");
    foreach my $genre (@{$genres}){
      $sth_select->execute($genre); # locate
      $sth_insert->execute($genre) if $sth_select->rows == 0; # missing, insert
    }
    $sth_select->finish();
    $sth_insert->finish();
    $self->{dbh}->commit(); # commit any changes
  };
  if($@){
    warn "anidb.pm: Database error: $@ [@{[$self->{dbh}->errstr()]}]\n";
    $self->{dbh}->rollback();
  }
}

# parses an anidb anime page and returns the scraped info
sub anidb_anime_parse {
  my ($self, $content) = @_;
  my %info;
  my %translation =
    ( 'Title:'      =>
      sub {
        $info{'maintitle'} = decode_entities($_[1]);
        $info{'maintitle'} =~ s/\s+\(\d+\)\s*$//; # get rid of that ID junk
        add_title($_[0], $info{'maintitle'});
      },

      'Jap. Kanji:' => \&add_title,
      'English:'    => \&add_title,
      'Kanji/Kana:' => \&add_title,

      'Genre:'      =>
      sub {
        my $str = $_[1];
        $str =~ s/ - .+$//;
        push @{$info{'genres'}}, split(/, /, $str);
      },

      'Type:' =>
      sub { $info{'type'} = $_[1] },

      'Episodes:' =>
      sub { $info{'numeps'} = $_[1] },

      'URL:' =>
      sub {
        $info{'url'} = $_[1];
        if($info{'url'} eq ''){ $info{'url'} = undef }
      },

      'Rating:' =>
      sub { if($_[1] =~ /(\d+\.\d+)/){ $info{'rating'} = $1 } },

      'Year:' =>
      sub {
        my ($info, $val) = @_;
        if($val =~ /\((\d{2})\.(\d{2})\.(\d{4}) till (\d{2})\.(\d{2})\.(\d{4})\)/){
          my @cpy = ($1, $2, $3, $4, $5, $6);
          map { $_ =~ s/^0+// } @cpy;
          $info->{'startdate'} = "$cpy[1]/$cpy[0]/$cpy[2]";
          $info->{'enddate'} = "$cpy[4]/$cpy[3]/$cpy[5]";
        }
      },

      'Tmp. Rating:' =>
      sub {
        if(not defined $info{'rating'} and $_[1] =~ /(\d+\.\d+)/){
          $info{'rating'} = $1
        }
      }
    );

  my $tree = HTML::TreeBuilder->new_from_content($content);
  foreach my $match ($tree->look_down('_tag', 'tr', \&match_two_row)){
    my @row = $match->content_list();
    my ($left, $right) = map {
      $_ = decode_entities(space_collapse($_->as_text()));
    } $match->content_list();
    #print "`$left' -> `$right'\n";
    if(defined $translation{$left}){
      $translation{$left}->(\%info, $right);
    }
  }
  $tree->delete;

  return \%info;
}

sub add_title {
  push @{$_[0]->{'titles'}}, decode_entities($_[1]);
}

sub strip {
  my $query = lc(shift); # lowcase input

  $query =~ s/\s+/ /g; # collaspe spaces
  $query =~ s/^\s+//;  # strip starting spaces
  $query =~ s/\s+$//;  # strip ending spaces

  return $query;
}

sub space_collapse {
  my $str = shift;
  $str =~ s/ +/ /g;
  $str =~ s/^ +//;
  $str =~ s/ +$//;
  return $str;
}

1;
