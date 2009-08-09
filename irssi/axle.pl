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

my (%axle_active_chans, $axle_key, $axle_tick, $filter, $axel_debug);

irssi_register();

# irssi_register: register module with IRSSI and init state
sub irssi_register {
    Irssi::settings_add_str($IRSSI{'name'}, 'axle_channels', '');
    Irssi::settings_add_str($IRSSI{'name'}, 'axle_filter', '.*');
    Irssi::settings_add_int($IRSSI{'name'}, 'axle_debug', 0);
    Irssi::signal_add('setup changed', 'load_globals');
    Irssi::timeout_add(60000, 'check_queue', 0);
    load_globals();
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
    $axel_debug = Irssi::settings_get_int('axle_debug');
}


# check_queue: get latest RSS items and make any announcements
# called once a minute to check Differential RSS messages
sub check_queue {
    return if not defined $filter;
    my $sock = dconnect() or return;
    foreach my $item (get_rss_items($sock)){
        Irssi::print("axel: new item: $item->{filename}") if $axel_debug;
        if($item->{filename} =~ $filter){
            chans_notify("ZOMG! $item->{filename} is out! <$item->{url}>");
        } else {
            Irssi::print("axel: item failed to match against $filter") if $axel_debug;
        }
    }
    dclose($sock);
}


# chans_notify: sends a message to all registered channels
sub chans_notify {
    my $msg = shift;

    foreach (keys %axle_active_chans){
        my $channel = Irssi::channel_find($_) or next;
        $channel->{server}->send_message($_, $msg, 0);
    }
}


# get_state: query Differential for its state
# this will update our state to match Differential's
sub get_state {
    my $sock = shift;

    # send query
    my $s = dquery($sock, 'STATE');
    return if failed_status($s);

    # get a line
    my ($reply, $key, $tick) = dgetline($sock);
    if($reply eq 'STATEIS' and defined $key and defined $tick){
        Irssi::print("axel: got state: $key $tick") if $axel_debug;
        $axle_key = $key;
        $axle_tick = $tick;
    } else {
        $axle_key = undef;
        $axle_tick = undef;
    }
}


# get_rss_items: query Differential for the latest RSS items
# requires $axle_tick to be in a global namespace and defined
sub get_rss_items {
    my $sock = shift;

    # get state if we havent got it
    if(not defined $axle_key or not defined $axle_tick){
        get_state($sock);
    }

    # send query
    my @cmd = ('GETRSS', $axle_key, $axle_tick);
    my $status = dquery($sock, @cmd) or return;
    if($status->{num} == 401){
        # state mismatch! request state and retry
        get_state($sock);
        $status = dquery($sock, @cmd);
    }

    # return on error (we tried our best)
    if(failed_status($status)){
        Irssi::print("axle: unable to query RSS feeds.");
        return;
    }

    # 'GETRSS' worked, process list response
    my @list;
    my $eol = 0;
    do {
        my ($resp, @args) = dgetline($sock) or return;
        if($resp eq '/LIST'){
            $eol = 1;
        } elsif($resp eq 'ITEM'){
            my ($item_tick, $fn, $url) = @args;
            $axle_tick = $item_tick if $item_tick > $axle_tick;
            push @list, { 'filename' => $fn, 'url' => $url };
        }
    } while(not $eol);

    # return the items
    return @list;
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
# returns status line or false on error
# example: dquery($socket, 'GETRSS', 7);
sub dquery {
    my ($sock, @cmd) = @_;

    # build the request, read and parse the reply
    my $cout = join("\t", @cmd);
    print $sock "$cout\n";
    my $status_line = <$sock>;
    chomp $status_line;
    my $response;
    if($status_line =~ /^(\d+)\s*(.+)/){
        $response = { num => $1, reason => $2, line => $status_line };
    } else {
        # strange response
        Irssi::print("Query '$cmd[0]' completely failed.");
        return;
    }

    # give the caller the response
    return $response;
}


# dgetline: gets a generic response line (tab delimited, NL terminated)
# returns response as an array
sub dgetline {
    my $sock = shift or return;

    my $r = <$sock>;
    chomp $r;

    return split /\t/, $r;
}


# dclose: close a Differential socket
sub dclose {
    my $sock = shift or return;
    print $sock "QUIT";
    close($sock);
}


# failed_status: process a dquery status line for failure
# returns true if it's a bad response, false if it's OK
sub failed_status {
    my $status = shift;

    # error if no status at all
    return 1 if not defined $status;

    # OK if 2xx code
    return 0 if $status->{num} >= 200 and $status->{num} < 300;

    # everything else is error
    return 1;
}

