# fun.pl: A silly irssi module.

use strict;
use Text::ParseWords;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.10';
%IRSSI = ( 'authors'     => 'Tristan Willy',
	   'contact'     => 'tristan.willy at gmail.com',
	   'name'        => 'Fun',
	   'description' => 'Fun channel triggers',
	   'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'fun_channels', '');
Irssi::settings_add_str($IRSSI{'name'}, 'fun_pikas',
			'Chuuuu!,Pika?,Pika ka pika\, Pikachu!,Pikapi!');

my @adverbs = ('vigorously', 'powerfully', 'lovingly',
	       'energetically', 'passionately', 'intensely',
	       'bountifully', 'thoughtlessly', 'timidly',
	       'satisfyingly', 'luxuriantly', 'sweetly',
	       'happily', 'enthusiastically');
my ($starttime, %fun_active_chans, @pikas, $only_channel);
$starttime = time();
load_globals();

Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('message irc notice', 'irc_notice');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map {
    $fun_active_chans{uc($_)} = 1;
    $only_channel = $_;
  } quotewords(',', 0, Irssi::settings_get_str('fun_channels'));
  if(scalar keys %fun_active_chans != 1){
    $only_channel = undef;
  }
  @pikas = quotewords(',', 0, Irssi::settings_get_str('fun_pikas'));
}

sub irc_notice {
  my ($server, $message, $from, $address, $to) = @_;
  my ($target, $cmd);

  # if non-public, target the sender
  if($message =~ /^\s*!(calc|uptime)/i){
    $target = $from;
    $cmd = 'notice';
  }

  # if no target, default to the channel
  # only one active channel is allowed
  if(not defined $target){
    if(not defined $only_channel){
      $server->command("notice $from Error: too many active " .
		       "channels for this trigger.");
      return 1;
    } else {
      $target = $only_channel;
      $cmd = 'msg';
    }
  }

  foreach my $msg (dispatch_message($server, $to, $from, $message)){
    $server->command("$cmd $target $msg");
  }

  return 1;
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  if(uc($to) eq uc($me) or $fun_active_chans{uc($to)}){
    foreach my $one_msg (dispatch_message($server, $to, $from, $message)){
      $server->command("msg $target $one_msg");
    }
  }

  return 1;
}

sub dispatch_message {
  my ($server, $to, $from, $message) = @_;
  my @text;

  my %chan_dispatch =
    ( '^\s*!pika' => \&trigger_pika,
      '^\s*!insult' => \&trigger_insult,
      '^\s*!uptime' => \&trigger_uptime,
      '^\s*!huggle([sz])?[^-]' => \&trigger_huggle,
      '^\s*!calc' => \&trigger_calc,
      '^\s*!fortune' => \&trigger_fortune,
      '^\s*!huggle-glom(s|p|ps)?' => \&trigger_huggle_glomp);
  # Check if it was for the channel we joined...
  foreach my $regex (keys %chan_dispatch){
    if($message =~ /$regex/i){
      my $msg = $chan_dispatch{$regex}->($server, $to,
					 $from, $message);
      eval {
	push @text, @{$msg} if defined $msg;
      };
      if($@){
	Irssi::print("Error: match on /$regex/ failed to return valid array ref.");
	Irssi::print("detail: to = $to, from = $from, message = $message");
	Irssi::print("perl error: $@");
	@text = ();
      }
    }
  }

  return @text;
}

sub trigger_uptime {
  my ($server, $to, $from, $message) = @_;
  my $script_uptime = secs2texttime(time() - $starttime);
  my $local_uptime = '?:?';
  if(open(FH, '/proc/uptime')){
    my $l = <FH>;
    if($l =~ /^(\d+\.\d+)/){
      $local_uptime = secs2texttime(int($1 + 0.5));
    }
    close(FH);
  }
  return [ "\x0306Bot Uptime [$script_uptime]\x0310 " .
	   "System Uptime [$local_uptime]" ];
}

sub trigger_pika {
  my ($server, $to, $from, $message) = @_;
  my @msg;

  if($#pikas >= 0){
    my $thispika = shift @pikas;
    push @pikas, $thispika;
    push @msg, $thispika;
  }

  return \@msg;
}

sub trigger_fortune {
  my ($server, $to, $from, $message) = @_;
  my @fortune;

  foreach my $line (`/usr/bin/fortune -s`){
    chomp $line;
    $line =~ s/\t/    /g;
    push @fortune, $line;
  }
  return \@fortune;
}

sub trigger_insult {
  my ($server, $to, $from, $message) = @_;
  my $who = 'Thou';
  if($message =~ /^!insult\s+(\S+)/i){
    $who = "$1: Thou";
  }
  my @Insults =
    (
     [qw(
	 artless bawdy beslubbering bootless churlish cockered clouted
	 craven currish dankish dissembling droning errant fawning
	 fobbing froward frothy gleeking goatish gorbellied impertinent
	 infectious jarring loggerheaded lumpish mammering mangled
	 mewling paunchy pribbling puking puny quailing rank reeky
	 roguish ruttish saucy spleeny spongy surly tottering unmuzzled
	 vain venomed villainous warped wayward weedy yeasty
	)],
     [qw(
	 base-court bat-fowling beef-witted beetle-headed boil-brained
	 clapper-clawed clay-brained common-kissing crook-pated
	 dismal-dreaming dizzy-eyed doghearted dread-bolted earth-vexing
	 elf-skinned fat-kidneyed fen-sucked flap-mouthed fly-bitten
	 folly-fallen fool-born full-gorged guts-griping half-faced
	 hasty-witted hedge-born hell-hated idle-headed ill-breeding
	 ill-nurtured knotty-pated milk-livered motley-minded onion-eyed
	 plume-plucked pottle-deep pox-marked reeling-ripe rough-hewn
	 rude-growing rump-fed shard-borne sheep-biting spur-galled
	 swag-bellied tardy-gaited tickle-brained toad-spotted
	 urchin-snouted weather-bitten
	)],
     [qw(
	 apple-john baggage barnacle bladder boar-pig bugbear bum-bailey
	 canker-blossom clack-dish clotpole coxcomb codpiece death-token
	 dewberry flap-dragon flax-wench flirt-gill foot-licker
	 fustilarian giglet gudgeon haggard harpy hedge-pig horn-beast
	 hugger-mugger jolthead lewdster loat maggot-pie malt-worm mammet
	 measle minnow miscreant moldwarp mumble-news nut-hook pigeon-egg
	 pignut puttock pumpion ratsbane scut skainsmate strumpet varlet
	 vassal whey-face wagtail
	)]
    );

  return [ "$who @{[ map { $$_[ int rand scalar @$_ ] } @Insults ]}." ];
}

sub trigger_huggle {
  my ($server, $to, $from, $message) = @_;
  my $huggles = join('', map { $_ = rand_color() . $_ } split('', 'huggles'));
  my @msg;

  if($message =~ /\s*!huggle(sz)?\s+(.+?)(\s+)?$/io){
    my $to_huggle = $2;
    push @msg, "\x0313<3 <3 <3 @{[rand_color() . $from]} " .
      "@{[rand_color() . $adverbs[int rand $#adverbs]]} $huggles " .
	"@{[rand_color() . $to_huggle]} \x0313<3 <3 <3";
  }

  return \@msg;
}

sub trigger_huggle_glomp {
  my ($server, $to, $from, $message) = @_;
  my @msg;

  if($message =~ /\s*!huggle-glom(s|p|ps)?\s+(.+?)(\s+)?$/io){
    my $to_huggle = $2;
    my @rc = (rand_color(), rand_color(), rand_color(), rand_color());
    push @msg,
      "\x0313*^-^* $rc[0]$from $rc[1]$adverbs[int rand $#adverbs] " .
	"$rc[2]huggle *GLOMPS* $rc[3]$to_huggle " .
	  "\x0313*^-^*";
  }

  return \@msg;
}

sub trigger_calc {
  my ($server, $to, $from, $message) = @_;
  my @msg;
  for($message){
    s/[^*+\/\(\) \.0-9-]+//g;
    s/^\s+//;
    my $res = eval("($_) || 'error'");
    $res = $res ? $res : 'error';
    push @msg, "$_ = $res";
  }

  return \@msg;
}

# Picks a random color except white and black
sub rand_color {
  return sprintf("\x03%02d", (int rand 13) + 2);
}

sub secs2texttime {
  my $sec = shift;
  $sec = int($sec + 0.5); # round second
  my $days = int($sec / 86400); $sec %= 86400;
  my $hours = int($sec / 3600); $sec %= 3600;
  my $minutes = int($sec / 60); $sec %= 60;

  my $base = sprintf("%d:%02d:%02d", $hours, $minutes, $sec);

  if($days <= 0){
    return $base;
  }

  if($days != 1){
    return sprintf("%d days ", $days) . $base;
  } else {
    return ("1 day " . $base);
  }

  return "~bug~";
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}
