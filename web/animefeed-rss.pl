#!/usr/bin/perl -w

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
  $dbh = DBI->connect("dbi:Pg:dbname=animefeed", undef, undef,
                      { RaiseError => 1,
                        PrintError => 0,
                        AutoCommit => 0 });
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
