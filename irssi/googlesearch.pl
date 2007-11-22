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
use Text::ParseWords;
use HTML::Entities;
use Compress::Zlib;
use URI::Escape;
use JSON;
use LWP;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = (
    'authors'     => 'Tristan Willy',
    'contact'     => 'tristan.willy at gmail.com',
    'name'        => 'Google Search',
    'description' => 'Google Search for irssi. Uses Google\'s AJAX API.',
    'license'     => 'GPL v2'
    );

Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_channels', '');
Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_site_url', '');
Irssi::settings_add_str($IRSSI{'name'}, 'gsearch_key', '');

Irssi::signal_add('event privmsg', 'irc_privmsg');

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));
  my (%gsearch_active_chans, $site_url, $ajax_key);

  # Are we triggered?
  if($message !~ /^\s*!google\s+(.+)/i){
    return 1;
  }
  my $encoded_query = uri_escape($1, "^A-Za-z0-9\-_.!~*'()+");

  # pull in settings
  map { $gsearch_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('gsearch_channels'));
  $site_url = Irssi::settings_get_str('gsearch_site_url');
  $ajax_key = Irssi::settings_get_str('gsearch_key');

  # verify settings and trigger perms
  if(not $site_url or not $ajax_key){
    Irssi::print("Google search: search detected, but settings not set.");
    return 1;
  }
  if(not (uc($to) eq uc($me) or $gsearch_active_chans{uc($to)})){
    return 1;
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
    $server->command("msg $target Error: Google died. The end is near.");
    return 1;
  }

  # Cut out the JS call and parse
  $results =~ s/^GwebSearch.RawCompletion\('\d+',//;
  my $resh = jsonToObj($results);

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