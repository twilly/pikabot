#!/usr/bin/env perl
# animefeed-rss.pl: animefeed cgi-bin script that generates a RSS feed from a database.
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
use CGI;
use DBI;
use XML::Writer;
use Digest::MD5 qw(md5_hex);
use HTTP::Date;

# Change if you are using https
my $scheme = 'http';
# This is so running locally will work
$ENV{HTTP_HOST} = 'localhost' if not defined $ENV{HTTP_HOST};
$ENV{REQUEST_URI} = "/cgi-bin/$0" if not defined $ENV{HTTP_HOST};

my $cgi = new CGI;
my $xml = new XML::Writer(UNSAFE => 1);
my ($dbh, $sth);
eval {
  $dbh = DBI->connect("dbi:Pg:dbname=pikabot", undef, undef,
                      { RaiseError => 1,
                        PrintError => 0,
                        AutoCommit => 0 });
  $dbh->do("SET search_path TO animefeed");
  $sth = $dbh->prepare("SELECT title,url,extract(epoch FROM stamp)," . 
                       "extract(month FROM stamp),extract(day FROM stamp),extract(year FROM stamp) " .
                       "FROM items WHERE age(current_timestamp, stamp) <= interval '2d' ORDER BY stamp DESC");
  $sth->execute();

  print $cgi->header(-type=>'application/rss+xml', -expires=>'+1d');
  $xml->startTag("rss", "version" => "2.0");
  $xml->startTag("channel");
  $xml->startTag("title"); $xml->characters("AnimeFeed"); $xml->endTag("title");
  $xml->startTag("link");
   $xml->characters("$scheme://$ENV{HTTP_HOST}$ENV{REQUEST_URI}");
  $xml->endTag("link");
  $xml->startTag("description");
  $xml->characters("Aggregated and cached anime RSS feeds.");
  $xml->endTag("description");
  while(defined (my $rowref = $sth->fetchrow_arrayref)){
    $xml->startTag("item");
     $xml->startTag("title"); $xml->characters($rowref->[0]); $xml->endTag("title");
     $xml->startTag("link"); $xml->characters(escape($rowref->[1])); $xml->endTag("link");
     $xml->startTag("description");
      $xml->characters("$rowref->[3]/$rowref->[4]/$rowref->[5] -=- $rowref->[0]");
     $xml->endTag("description");
     $xml->startTag("guid", "isPermaLink" => "false");
      $xml->characters(md5_hex($rowref->[0] . $rowref->[2]));
     $xml->endTag("guid");
     $xml->startTag("pubDate");
      $xml->characters(time2str($rowref->[2]));
     $xml->endTag("pubDate");
    $xml->endTag("item");
  }
  $xml->endTag("channel");
  $xml->endTag("rss");
  $xml->end();
  $sth->finish;
  $dbh->disconnect;
};
if($@){
  my $err = $@;
  $dbh->disconnect if defined $dbh;
  print $cgi->header(-status=>500);
  print "Internal error: $err\n";
}
exit 0;

sub escape {
  my $str = shift;
  $str =~ s/([\[\]\(\) ])/@{[sprintf '%%%02X', ord($1)]}/g;
  return $str;
}
