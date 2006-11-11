#!/usr/bin/env perl
#
# jedict-driver.pl: a driver for jedict.pm. used for testing
#
# Copyright (C) 2006   Andreas Högström <superjojo at gmail.com>
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
use utf8;
use lib "../modules";
use jedict;

if ($#ARGV < 1) {
	warn "Usage: $0 [jap|eng|0] [search string]\nUsage: $0 update [edict file]\n";
	exit 1;
}
my $type = shift;
my $string;
my $an;
foreach $an (0 .. $#ARGV) {
	$string .= " " unless $an == 0;
	$string .= "$ARGV[$an]";
}
my $jedict = jedict->new('Database' => 'pikabot') or die "jedict creation error: $!\n";

if ($type eq "update") {
	print "Parsing file to database. (This may take some time)\n";
	my $added = $jedict->update_database($string) or die("FAIL: $!");
	print "Added $added lines\n";
} else {
	if ($type eq "eng" || $type eq "jap") {
		my $found = 0;
		foreach my $res ($jedict->search($string, $type)){
			$found = 1;
			if(defined $res){
				print "Kanji: " . ($res->{kanji} eq 1337 ? "N/A" : $res->{kanji}) . "\tKana: $res->{kana}\tEnglish: $res->{english}\n";
			}
		}
		print "Your search: \"$string\" returned no results.\n" unless $found;
	} else {
		if ($type == 0) {
			my $found = 0;
			foreach my $res ($jedict->search($string)) {
				$found = 1;
				if (defined $res) {
					print "Kanji: " . ($res->{kanji} eq 1337 ? "N/A" : $res->{kanji}) . "\tKana: $res->{kana}\tEnglish: $res->{english}\n";
				}
			}
			print "No results\n" unless $found;
		} else {
			warn "Usage: $0 [jap|eng|0] [search string]\nUsage: $0 update [edict file]\n";
			exit 1;
		}
	}
}
exit 0;
