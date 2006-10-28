# autovoice.pl: Give +v to fservs.

use strict;
use Text::ParseWords;
use LWP;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
	   'contact'     => 'tristan.willy at gmail.com',
	   'name'        => 'autovoice',
	   'description' => 'auto-voice fservs',
	   'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'autovoice_channels', '');

my (%active_chans, %state);
load_globals();

Irssi::signal_add('message irc notice', 'irc_notice');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('autovoice_channels'));
}

sub irc_notice {
  my ($server, $message, $from, $address, $to) = @_;
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # Check if it was for the channel we joined...
  if(uc($to) eq uc($me)){
    if(is_fserv_notice($message) and
       have_mode($me, '[%@]') and
       not have_mode($from, '.') and # they should have no mode on them
       is_before_timeout()){
      #$channel->voice($from);
    }
  }
}

# When we know someone needs voice then give it to them
# without waiting until the next !list
sub irc_join {
}

sub is_fserv_notice {
  my $msg = shift;
  my @tests = ( 'fserv\s+active', 'file\s+server\s+online', 'XDCC' );

  # Run each regex against the message
  foreach my $test (@tests){
    if($msg =~ /$test/i){
      return 1;
    }
  }

  return 0; # nope, not a fserv notice
}

sub have_power {
  my $nick;
}
