#!/usr/bin/perl -w
package anidb;
# anidb.pm:
#   Get crap from AniDB.net
#
# Copyright (C) 2006-2009  Tristan Willy  <tristan.willy at gmail.com>
# Copyright (C) 2009  Justin "idiot" Lee  <kool.name at gmail.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.


use strict;
use warnings;

use DBI;
use anidb::Cacher;
use anidb::Scraper;



# Defaults and Globals

  # DBI Stuff
sub DBI_RAISE_ERROR()
  { 1 } # do not edit this flag, please~!
sub DBI_PRINT_ERROR()
  { 0 }
sub DBI_AUTOCOMMIT()
  { 0 }

sub DBI_CONNECT_STRING()
  { 'dbi:SQLite(AutoCommit=>%d):dbname=%s' }

  # Scrape Stuff
sub SCRAPE_SCRAPES_TO_SAVE()
  { 2 } # this should be a small number, heh
sub SCRAPE_SEARCH_URL()
  { 'http://anidb.net/perl-bin/animedb.pl?show=animelist&adb.search=%s&do.search=search' }
sub SCRAPE_ANIME_URL()
  { 'http://anidb.net/perl-bin/animedb.pl?show=anime&aid=%d' }

sub SCRAPE_LWP_USER_AGENT()
  { 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1; fixing your API would make life easier) Gecko/20061010 Firefox/2.0' }
sub SCRAPE_LWP_TIMEOUT()
  { 30 }
sub SCRAPE_LWP_REFERER()
  { 'http://www.anidb.net/perl-bin/animedb.pl' }