#!/usr/bin/env perl
# googlesearch.pl: !google search trigger for irssi
#
# Copyright (C) 2007 Tristan Willy <tristan.willy at gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Basename;
use Text::ParseWords;
use HTML::Entities;
use Compress::Zlib;
use URI::Escape;
use JSON;
use LWP;

BEGIN {
  eval { Irssi::Core::is_static() };
  if(not $@){
    use vars qw($VERSION %IRSSI);
    require Irssi;
    $VERSION = '0.01';
    %IRSSI = (
        'authors'     => 'Tristan Willy',
        'contact'     => 'tristan.willy at gmail.com',
        'name'        => 'Google Search',
        'description' => 'Google Search for irssi. Uses Google\'s AJAX API.',
        'license'     => 'GPL v2'
        );
  } else {
    require Getopt::Std;
    Getopt::Std->import;
  }
}

sub in_irssi {
  eval { Irssi::Core::is_static() };
  return (not $@);
}

if(in_irssi()){
  Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_channels', '');
  Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_site_url', '');
  Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_key', '');

  Irssi::signal_add('event privmsg', 'irc_privmsg');
} else {
  my %opt;
  getopts("hpls:k:", \%opt) or die;
  print_help() and exit if $opt{h};
  die "-s and -k options are required\n"
    if not defined $opt{s} or not defined $opt{k};

  my $terms = join(' ', @ARGV);
  my $result = google_search($opt{s}, $opt{k}, $terms);

  if($opt{p}){
    use Data::Dumper;
    print Dumper($result);
  }

  foreach my $hit (@{$result->{results}}){
    print
      untag(decode_entities($hit->{title})) . " " .
      "<$hit->{unescapedUrl}>\t";
    my $content = decode_entities($hit->{content});
    $content =~ s/\s+/ /g;
    if(length $content > 5){
      print untag($content);
    } else {
      print " ";
    }
    print "\n";

    last if $opt{l}; # I'm Feeling Lucky
  }
}

sub print_help {
  my $script = basename($0);
  print <<"__HELP__";
Options: $script [options] -s <site url> -k <ajax key> <search terms>
-= Options =-

  -h               : This message.
  -p               : Print raw dump of google's returned object.
  -l               : Print only first result (I'm Feeling Lucky).
  -s <site>        : Required site url.
  -k <key>         : Required ajax key.
__HELP__
}

sub error {
  my $msg = join(' ', @_);
  if(in_irssi()){
    Irssi::print($msg);
  } else {
    die "$msg\n";
  }
}

sub google_search {
  my ($site_url, $ajax_key, $query) = @_;

  my $encoded_query = uri_escape($query, "^A-Za-z0-9\-_.!~*'()+");

  # verify settings and trigger perms
  if(not $site_url or not $ajax_key){
    error("Missing site url and ajax key.");
    return;
  }
  my $agent = LWP::UserAgent->new(
      'agent' =>
        'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) ' .
        'Gecko/20060124 Firefox/1.5.0.1');
  my $reply = $agent->get(
      'http://www.google.com/uds/GwebSearch?' .
      'callback=GwebSearch.RawCompletion&' .
      'context=0&lstkp=0&rsz=large&hl=en&gss=.com&' .
      'sig=827f423b91df4dc97aaeb3a17d5711a0&' .
      'q=' . $encoded_query . '&' .
      'key=' . $ajax_key . '&v=1.0',
      'Referer' => $site_url);

  my $results;
  if($reply->is_success){
    if($reply->content_encoding and
        $reply->content_encoding eq 'gzip'){
      $results = Compress::Zlib::memGunzip($reply->content);
    } else {
      # assume they're plain-text...
      $results = $reply->content;
    }
  } else {
    error("Google died. The end is near.");
    return;
  }

  # Cut out the JS call and parse
  # Edits by dean:
  #   JSON.pm was complaining about left over crap at the
  #   end of the parse, turns out, there was crap there! :D
  #   I added an extra substitution, and made the first one
  #   less restrictive (which is arguably not better).
  $results =~ s/^.*?\{/\{/o;
  $results =~ s/, 200, null, 205\)$//oi;

  # Edits by dean:
  #   All I had was the newest version of JSON.pm which yelled
  #   at me for using depricated methods, so I updated this line.
  return from_json($results);
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));
  my (%gsearch_active_chans, $site_url, $ajax_key);

  # Are we triggered?
  if($message !~ /^\s*!google\s+(.+)/i){
    return 1;
  }
  my $query = $1;

  # pull in settings
  map { $gsearch_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('gsearch_channels'));
  $site_url = Irssi::settings_get_str('gsearch_site_url');
  $ajax_key = Irssi::settings_get_str('gsearch_key');

  # permitted?
  if(not (uc($to) eq uc($me) or $gsearch_active_chans{uc($to)})){
    return 1;
  }

  my $resh = google_search($site_url, $ajax_key, $query);
  if(not $resh){
    $server->command("msg $target Error: Google is speaking gibberish.");
    return 1;
  }

  if($#{$resh->{results}} < 0){
    $server->command("msg $target No results.");
    return 1;
  }

  my $first = $resh->{results}[0];
  $server->command("msg $target " .
    untag(decode_entities($first->{title})) . " <$first->{unescapedUrl}>\n");
  return 1;
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}

# powerman's HTML striper: http://www.perlmonks.org/?node_id=161281
sub untag {
  local $_ = $_[0] || $_;
# ALGORITHM:
#   find < ,
#       comment <!-- ... -->,
#       or comment <? ... ?> ,
#       or one of the start tags which require correspond
#           end tag plus all to end tag
#       or if \s or ="
#           then skip to next "
#           else [^>]
#   >
  s{
    <               # open tag
    (?:             # open group (A)
      (!--) |       #   comment (1) or
      (\?) |        #   another comment (2) or
      (?i:          #   open group (B) for /i
        ( TITLE  |  #     one of start tags
          SCRIPT |  #     for which
          APPLET |  #     must be skipped
          OBJECT |  #     all content
          STYLE     #     to correspond
        )           #     end tag (3)
      ) |           #   close group (B), or
      ([!/A-Za-z])  #   one of these chars, remember in (4)
    )               # close group (A)
    (?(4)           # if previous case is (4)
      (?:           #   open group (C)
        (?!         #     and next is not : (D)
          [\s=]     #       \s or "="
          ["`']     #       with open quotes
        )           #     close (D)
        [^>] |      #     and not close tag or
        [\s=]       #     \s or "=" with
        `[^`]*` |   #     something in quotes ` or
        [\s=]       #     \s or "=" with
        '[^']*' |   #     something in quotes ' or
        [\s=]       #     \s or "=" with
        "[^"]*"     #     something in quotes "
      )*            #   repeat (C) 0 or more times
    |               # else (if previous case is not (4))
      .*?           #   minimum of any chars
    )               # end if previous char is (4)
    (?(1)           # if comment (1)
      (?<=--)       #   wait for "--"
    )               # end if comment (1)
    (?(2)           # if another comment (2)
      (?<=\?)       #   wait for "?"
    )               # end if another comment (2)
    (?(3)           # if one of tags-containers (3)
      </            #   wait for end
      (?i:\3)       #   of this tag
      (?:\s[^>]*)?  #   skip junk to ">"
    )               # end if (3)
    >               # tag closed
   }{}gsx;          # STRIP THIS TAG
  return $_ ? $_ : "";
}
