# deref.pl: A URL dereference module.

use strict;
use Text::ParseWords;
use LWP;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
	   'contact'     => 'twilly@ucsc.edu',
	   'name'        => 'Deref',
	   'description' => 'Dereferences URL redirects (ex: tinyurl).',
	   'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'deref_channels', '');

my %deref_active_chans;
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $deref_active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('deref_channels'));
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me) or $deref_active_chans{uc($to)}){
    if($message =~ /^\s*!deref(erence)?\s(\S+)/i){
      trigger_deref($server, $target, $to, $from, $address, $2);
    }
  }

  return 1;
}

sub trigger_deref {
  my ($server, $target, $to, $from, $address, $url) = @_;
  my $agent = LWP::UserAgent->new('max_redirect' => 0,
				  'agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.1) Gecko/20060124 Firefox/1.5.0.1');
  my $r = $agent->get($url);
  if($r->code == 302 or $r->code == 301){
    $server->command("msg $target Location: @{[$r->header('Location')]}");
  } else {
    $server->command("msg $target Segmentation Fault");
  }
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
