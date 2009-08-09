# axle.pl: read and route events from Differential
# Copyright (C) 2009  Tristan Willy <tristan.willy at gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
use strict;
use Text::ParseWords;
use IO::Socket;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '1.00';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'axle',
           'description' => 'Differential event router.',
           'license'     => 'GPL v3' );

my (%axle_active_chans, $axle_tick, $filter);

irssi_register();

# irssi_register: register module with IRSSI and init state
sub irssi_register {
    Irssi::settings_add_str($IRSSI{'name'}, 'axle_channels', '');
    Irssi::settings_add_str($IRSSI{'name'}, 'axle_filter', '.*');
    Irssi::signal_add('setup changed', 'load_globals');
    Irssi::timeout_add(60000, 'check_queue', 0);
    load_globals();
    $axle_tick = get_tick();
    Irssi::print("Axle loaded. Current Differential tick: $axle_tick");
}


# load_globals: load settings from IRSSI
sub load_globals {
    $axle_active_chans{uc($_)} = 1 foreach
        quotewords(',', 0, Irssi::settings_get_str('axle_channels'));
    my $fstr = Irssi::settings_get_str('axle_filter');
    eval { $filter = qr/$fstr/i; };
    if($@){
        Irssi::print("/$fstr/ is not valid: $@");
        $filter = undef;
    }
}


# check_queue: get latest RSS items and make any announcements
# called once a minute to check Differential RSS messages
sub check_queue {
    return if not defined $filter;
    foreach my $item (get_rss_items()){
        if($item->{filename} =~ $filter){
            chans_notify("ZOMG! $item->{filename} is out! <$item->{url}>");
        }
    }
}


# chans_notify: sends a message to all registered channels
sub chans_notify {
    my $msg = shift;

    foreach (keys %axle_active_chans){
        my $channel = Irssi::channel_find($_) or next;
        $channel->{server}->send_message($_, $msg, 0);
    }
}


# get_tick: query Differential for its current time
# returns current Differential tick or zero
sub get_tick {
    my $sock = dcq('TICK') or return;

    my $resp = <$sock>;
    my $dtick = $1 if $resp =~ /^TICKIS\s+(\d+)/;
    dclose($sock);

    if(defined $dtick){
        return $dtick;
    } else {
        return 0;
    }    
}


# get_rss_items: query Differential for the latest RSS items
# requires $axle_tick to be in a global namespace and defined
sub get_rss_items {
    if(not defined $axle_tick){
        Irssi::print("get_rss_items: precondition not met");
        return;
    }

    my $sock = dcq('GETRSS', $axle_tick) or return;
    # process list response
    my @list;
    while(<$sock>){
        chomp;
        my @field = split /\t/;
        my $resp = shift @field;
        if($resp eq '/LIST'){
            last;
        }
        if($resp eq 'ITEM'){
            my ($item_tick, $fn, $url) = @field;
            $axle_tick = $item_tick if $item_tick > $axle_tick;
            push @list, { 'filename' => $fn, 'url' => $url };
        }
    }
    dclose($sock);

    # return the items
    return @list;
}


# dcq: Differential connect and query. Connects and issues a command.
# returns socket handle, or undef on error
sub dcq {
    my @cmd = @_;

    my $sock = dconnect() or return;
    my $status = dquery($sock, @cmd) or do {
        Irssi::print("Query '$cmd[0]' completely failed.");
        dclose($sock);
        return;
    };
    if($status->{num} != 200){
        Irssi::print("Command '$cmd[0]' failed: $status->{line}");
        dclose($sock);
        return;
    }

    return $sock;
}


# deconnect: connect to Differential
# returns a socket handle or undef on error
sub dconnect {
    my $sock = new IO::Socket::UNIX(
            Peer => '/tmp/ircpipe.sock',
            Type => SOCK_STREAM) or do {
        Irssi::print("Failed to connect to Differential: $!");
        return;
    };

    return $sock;
}


# dquery: sends a command to Differential
# returns status line
# example: dquery($socket, 'GETRSS', 7);
sub dquery {
    my ($sock, @cmd) = @_;

    my $cout = join("\t", @cmd);
    print $sock "$cout\n";
    my $status_line = <$sock>;
    chomp $status_line;
    if($status_line =~ /^(\d+)\s*(.+)/){
        return { num => $1, reason => $2, line => $status_line };
    } else {
        # strange response
        return;
    }
}


# dclose: close a Differential socket
sub dclose {
    my $sock = shift or return;
    print $sock "QUIT";
    close($sock);
}

