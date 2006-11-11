# jedict.pl: japanese <-> english dictionary irssi script
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

use strict;
use Text::ParseWords;
use jedict;
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Andreas \'Joho\' Högström',
	   'contact'     => 'superjojo at gmail.com',
	   'name'        => 'jedict-trigger',
	   'description' => 'Does japanese-english lookups from edict psql database' );


Irssi::settings_add_str($IRSSI{'name'}, 'jedict_channels', '');

my (%jedict_active_chans);
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $jedict_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('jedict_channels'));
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $jedict_active_chans{uc($to)}){
    if ($message =~ /^[^!]*!(lookup|jedict)\s+(.+)/i) {
      trigger_jedict($server, $target, $to, $from, $address, $2);
    }
  }

  return 1;
}

sub trigger_jedict {
	my ($server, $target, $to, $from, $address, $string) = @_;
	
	my $jedict = new jedict('Database' => 'pikabot') or do {
			$server->command("msg $target \x0311jedict: Error pulling up jedict module.");
			return;
		};

	# compress spaces
	$string =~ s/\s+/ /g;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	
	my @result = $jedict->search($string);
	if($#result < 0){
		$server->command("msg $target jedict: No Results");
		$jedict->close();
		return;
	}
	if ($#result >= 0) {
		my $header;
		my $counter = 0;
		if ($#result > 1) {
			$header = "\x0313jedict Results (2 of $#result):\x0311";
		} else {
			$header = "\x0313jedict Results:\x0311";
		}
		my $msgbuff = $header;
		foreach my $res (@result){
			$counter++;
			my $prevstate = $msgbuff;
			my $item;
			$item .= " [" . ($res->{kanji} eq 1337 ? "" : "Kanji: $res->{kanji}") . " Kana: $res->{kana} English: $res->{english}]";
			if (length($msgbuff . $item) > 256) { # prevent overflow
				$server->command("msg $target $prevstate");
				$msgbuff = $header . $item;
			} else {
				$msgbuff .= $item;
			}
			last if $counter == 2;
		}
		$server->command("msg $target $msgbuff");
	}
	$jedict->close();
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
