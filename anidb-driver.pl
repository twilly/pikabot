#!/usr/bin/perl -w
#
# anidb-driver.pl: a driver for anidb.pm. used for testing

use strict;

push @INC, '.';
use anidb;

if($#ARGV < 0){
  warn "Usage: $0 [title] <optional more titles>\n";
  exit 1;
}

my $anidb = anidb->new('Database' => 'anidb-nextgen');
  or die "anidb creation error: $!\n";

# run queries
map { search_title($_) } @ARGV;
exit 0;

sub search_title {
  my $title = shift;
  my @aids;

  print "= Title Hits =\n";
  foreach my $tq_result ($anidb->title_query($title)){
    if(defined $tq_result){
      printf "%-20s ID:%d\n", $tq_result->{title}, $tq_result->{id};
      push @aids, $tq_result->{id};
    }
  }

  foreach my $aid (@aids){
    print "= ID:$aid =\n";
    foreach my $aq_result ($anidb->anime_query($aid)){
      print_title($aq_result);
    }
  }
}

sub print_title {
  my $info = shift;

  print "{ID:$info->{aid}} ";
  foreach my $title (@{$info->{titles}}){
    print "<$title> ";
  }

  print "Genre: [ @{$info->{genres}} ] " if $#{$info->{genres}} >= 0;
  print "#Eps: [ $info->{numeps} ] " if defined $info->{numeps};
  print "Rating: [ $info->{rating} ] " if defined $info->{rating};
  print "URL: [ $info->{url} ] " if defined $info->{url};
  print "AniDB: [ http://anidb.info/a$info->{aid} ]";

  print "\n";
}
