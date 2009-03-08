#!/usr/bin/env perl
#
# anidb-driver.pl: a driver for anidb.pm (used for testing)
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

use lib "../modules";
use anidb;

# go full UTF
use utf8;
binmode STDOUT, ":utf8";

if($#ARGV < 0){
  warn "Usage: $0 [title] <optional more titles>\n";
  exit 1;
}

my $anidb = anidb->new('Database' => 'pikabot.db')
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
      if(not defined $aq_result){
        print "Error: no result\n";
      } else {
        print_title($aq_result);
      }
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
