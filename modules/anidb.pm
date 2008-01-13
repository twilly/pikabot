# anidb.pm: AniDB screen-scraper module (UDP protocol sucks ass)
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
package anidb;

my $debug_enable = 0;

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
                 { RaiseError => 1, PrintError => 0,  AutoCommit => 0 })
      or return undef;

  # change to anidb schema
  $params{'Schema'} = exists $params{'Schema'} ? $params{'Schema'} : 'anidb';
  eval {
    $self->{dbh}->do("SET search_path TO $params{'Schema'}");
  };
  if($@){
    $self->{dbh}->disconnect;
    return undef;
  }

  # make a LWP object for quering anidb
  my $ua = LWP::UserAgent->new() or return undef;
  $ua->timeout(30);
  $ua->agent('Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1) ' .
             'Gecko/20061010 Firefox/2.0');
  $self->{ua} = $ua;

  return bless $self, $type;
}

sub close {
  my $self = shift;
  eval { $self->{dbh}->rollback };
  eval { $self->{dbh}->disconnect };
}

sub DESTORY {
  my $self = shift;
  anidb::close($self);
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
    if($#{$titles} >= 0){
      title_insert($self, $query, $titles);
    }
  }

  if(defined $titles){
    return @{$titles};
  } else {
    return ();
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
    #warn "anidb.pm: Database error: $@\n";
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
    #warn "anidb.pm: stupid programmer alert";
    return undef;
  }
  if($id !~ /^\d+$/){
    #warn "anidb.pm: anime_search: $id is not a number\n";
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
    #warn "anidb.pm: error: $@\n";
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
    #warn "anidb.pm: database error: $@\n";
    eval { $self->{dbh}->rollback() };
  }
}

sub download_and_parse {
  my ($self, $url, $parser) = @_;

  debug("url = $url");

  # prepare a request
  my $request = HTTP::Request->new(GET => $url);
  $request->header('Referer' => 'http://www.anidb.net/perl-bin/animedb.pl');

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
    #warn "anidb.pm: error downling anidb page: " . $page->status_line() . "\n";
  }

  return undef;
}

# runs a anime query off anidb
sub anidb_anime {
  my ($self, $id) = @_;

  my $info =
    download_and_parse
      ($self,
       "http://www.anidb.net/perl-bin/animedb.pl?show=anime&aid=$id",
       \&anidb_anime_parse) or return undef;
  $info->{aid} = $id;
  return $info;
}

# Runs a search off anidb
sub anidb_search {
  my ($self, $query) = @_;

  # AniDB requires, for some stupid reason, spaces to be escaped as '+'
  # (normally they can be either + or %20).
  # XXX: Queries cannot contain '+' in them now, but I don't care.
  $query =~ s/\s+/\+/g;
  $query = uri_escape($query, "^A-Za-z0-9\-_.!~*'()+");
  my $url = "http://www.anidb.net/perl-bin/animedb.pl?show=animelist&adb.search=" .
            $query .
            "&do.search=search";
  debug("query = $query");
  return download_and_parse
    ($self, $url, \&anidb_search_parse);
}

# parses anidb search HTML
# note: anidb will return the anime title page if there is only one hit
#       this should deal with that case to reduce load
sub anidb_search_parse {
  my ($self, $content) = @_;
  my $tree = HTML::TreeBuilder->new_from_content($content);
  my @titles;

  if(defined (my $ele_aid = $tree->look_down('_tag' => 'input', 'type' => 'hidden', 'name' => 'aid'))){
    # Single hit. Parse the page and return a single-element array with the title
    debug("single title hit");
    my $page = anidb_anime_parse($self, $content);
    anime_insert($self, $page);
    push @titles, { 'id' => $ele_aid->attr('value'), 'title' => $page->{'maintitle'} };
  } else {
    # Multiple hits. Lets walk down the table.
    debug("multiple title hits");
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
    return [];
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
    #warn "anidb.pm: error: $@\n";
    eval { $self->{dbh}->rollback() };
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
    #warn "anidb.pm: Database error: $@ [@{[$self->{dbh}->errstr()]}]\n";
    eval { $self->{dbh}->rollback() };
  }
}

# parses an anidb anime page and returns the scraped info
sub anidb_anime_parse {
  my ($self, $content) = @_;
  my %info;
  my %translation =
    ( 'Main Title'      =>
        sub {
          $info{'maintitle'} = decode_entities($_[1]);
          $info{'maintitle'} =~ s/\s+\(a?\d+\)\s*$//; # get rid of that ID junk
          add_title($_[0], $info{'maintitle'});
        },
      'Kanji/Kana' => \&add_title, # XXX: Dead?
      'Official Title' => \&add_title,
      'English'    => \&add_title, # XXX: Dead?

# There are too many titles as is.
#     'Synonym' => 
#       sub {
#         my ($infohref, $value) = @_;
#         map { add_title($infohref, $_) } split(/,\s*/, $value);
#       },

      'Categories'      => # Genre is now Catagories
        sub {
          my $str = $_[1];
          $str =~ s/\s+-\s+.*$//;
          push @{$info{'genres'}}, split(/,\s+/, $str);
         },

      'Type' =>
        sub {
          if($_[1] =~ /([^,]+),\s*(\d+)\s*episodes/){
            $info{'type'}   = $1;
            $info{'numeps'} = $2;
          } else {
            $info{'type'} = $_[1];
          }
        },

      'Resources' =>
        sub {
          my ($info, $value, $value_element) = @_;
          foreach my $link ($value_element->look_down('_tag', 'a')){
            if($link->tag() eq 'a' and
               $link->as_text() =~ /official page/i){
              $info{'url'} = $link->attr('href');
            }
          }
        },

      'Rating' =>
        sub { if($_[1] =~ /(\d+\.\d+)/){ $info{'rating'} = $1 } },

      'Year' =>
        sub {
          my ($info, $val) = @_;
          if($val =~ /(\d{1,2})\.(\d{1,2})\.(\d{4})(\s+till\s+(\?|(\d{1,2})\.(\d{1,2})\.(\d{4})))?/){
            my @cpy = ($1, $2, $3, $6, $7, $8);
            my $date_two = $5;
            map { $_ =~ s/^0+// if defined $_ } @cpy;
            $info->{'startdate'} = sprintf "%4d-%02d-%02d", $cpy[2], $cpy[1], $cpy[0];
            if(defined $date_two and $date_two !~ /\?/){
              $info->{'enddate'} = sprintf "%4d-%02d-%02d", $cpy[5], $cpy[4], $cpy[3];
            }
          }
        },

      'Tmp. Rating' =>
        sub {
          if(not defined $info{'rating'} and $_[1] =~ /(\d+\.\d+)/){
            $info{'rating'} = $1
          }
         }
    );

  # This is the core parser for a show page.
  # The trick here is to locate the definition piece and find field/value
  # pairs. Each pair is passed into a translation table that changes the data
  # as it sees fit.
  my $tree = HTML::TreeBuilder->new_from_content($content);
  my $anime_deflist = $tree->look_down('_tag', 'div', 'class', qr/.*g_definitionlist\s+data.*/i)
    or do { return undef }; # we're interested in the core anime info
  foreach my $field ($anime_deflist->look_down('_tag', 'th', 'class', qr/field/i)){
    if(not $field->parent()){ next } # this shouldn't arise
    my $value = $field->parent()->look_down('_tag', 'td', 'class', qr/value/i)
      or next; # this shouldn't arise either
    # 'Official Title' now includes little icons that we need to ignore.
    if($value->look_down('_tag', 'div', 'class', qr/icons/) and
       $value->look_down('_tag', 'span', 'class', undef)){
      $value = $value->look_down('_tag', 'span', 'class', undef);
    }
    my ($left, $right) = map {
      decode_entities(space_collapse($_->as_text()));
    } ($field, $value);
    if(defined $translation{$left}){
      $translation{$left}->(\%info, $right, $value);
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

sub debug {
  if($debug_enable){
    my $msg = shift;
    my @stack = caller(1);
    warn "$stack[3]: $msg\n";
  }
}

1;
