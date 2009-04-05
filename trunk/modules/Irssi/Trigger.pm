package Irssi::Trigger;
# Author:
#   Justin "Dean_Kreger" Lee   < cuteguy at honobono dot cc >
# License:
#   GNU GPL Version 2   < http://gnu.org/licenses >
# To do:
#   - allow on-the-fly channel modification for global (and local) channels
#   - add a "trigger header" field, that gets (optionally) appened to trigger (E.G: '^\s*!')
#   - allow global choice of case sensitive or insensitive trigger matching, for now just use "(?i)" and "(?i:)"
#   - add "local" channels for each trigger on top of global channels
#   - get rid of global parser, let each trigger choose it's own
#   - get rid of assumption set on 2009-04-01
#   - allow for a "default" trigger for crap that doesn't match explicitly... could do stuff like spam filtering, whatever (not needed by Cuteb0t, so not on priority list)
# History:
#   2009-04-05:
#     - new scheme for triggers implemented, no code actually needed to be changed here! :D
#   2009-04-03:
#     - disregard the entry below, reworked the trigger finder again... all regexes from user should use (?:) instead of ()
#     - modified the matching regex for triggers (now you don't specify '^\s*' at the start or '\s*' after the trigger)
#     - added new feature idea thing: if trigger regex gives a DEFINED $1, then that is returned after "message": message, trigger, nick, address, target, server_rec
#     - added some new to-dos
#   2009-04-02:
#     - WORKING ALPHA!!!! :D
#     - made channel check subroutine
#     - ran s/croak/warn, croak/ over the document for better error checking
#     - fixed "register" and "unregister" to be magic
#     - coded "gazelle", "ike" and "_find_trigger" subs
#     - new naming scheme
#     - split _delete_by_regex into two new subs (one for hash, one for array)
#     - reworked assumption slightly
#     - changed what "methods" should return: message, nick, address, target, server_rec (target should still be undef if the message was private)
#     - changed parsers around
#     - rewrote "new" method
#     - changed "$self" from hash to array for "speed", and so I don't have to make a naming scheme
#     - whole bunch of other crap
#   2009-04-01:
#     - assume that this is ONLY used for public/private MESSAGES no notices, commands, server crap, whatever
#     - initial layout

use strict;
use warnings;

use Carp;


my %PARSER = (
  'MESSAGE' => sub {
    my ($server, $message, $nick, $address, $target) = @_;

    (ref($server) and
      defined($message) and
        defined($nick) and
          defined($address)) or
            return (undef);

    if (defined($target)) {
      return ($message, $nick, $address, $target, $server);
    } else {
      return ($message, $nick, $address, undef, $server);
    }
  },
  'PRIVMSG' => sub { # old method, provided as an example?
    my ($server, $data, $nick, $address) = @_;
    my ($target, $message) = split(/\s+:/,$data);

    (ref($server) and
      defined($message) and
        defined($nick) and
          defined($address)) or
            return (undef);

    if (defined(_find_target($target))) { # if it's not for a channel, then it MUST be for me... baka pc ;-)
      return ($message, $nick, $address, $target, $server);
    } else {
      return ($message, $nick, $address, undef, $server);
    }
  },
  'PASSTHROUGH' => sub { # provided to escape my assumptions, if I need to :)
    return (@_);
  },
);


sub _check_channel ($\@);
sub _delete_key_by_regex ($$);
sub _find_target ($); # crappy sub by pc ;-), modded by dean to have even *less* functionality
sub _delete_element_by_regex ($$$);
sub _find_trigger ($\%);



# Methods.

sub new {
  my $class = shift;
  my ($config) = @_;

  ref($config) eq 'HASH' or
    warn, croak 'Malformed configuration received ';

  my $self = [ # might re-organize these later, who knows
    { %PARSER }, # 0: add default parsers
    undef, # 1: parser to use
    {}, # 2: triggers
    [], # 3: global channels (triggers can have their own channels, too)
    0, # 4: support overloading?
    0, # 5: register flag
    0, # 6: unregister flag
    0, # 7: ready for action ... flag
  ];

  (exists($config->{'OVERLOADING'}) and
    $config->{'OVERLOADING'}) and
      $self->[4] = 1;
  exists($config->{'GLOBAL CHANNELS'}) and do {
    ref($config->{'GLOBAL CHANNELS'}) eq 'ARRAY' or
      warn, croak 'Malformed field "GLOBAL CHANNELS" received in configuration ';

    @{$self->[3]} = grep { defined } @{$config->{'GLOBAL CHANNELS'}};
  };
  defined($config->{'PARSER'}) and
    $self->[1] = $config->{'PARSER'};

  return (bless $self, $class);
}

# This one parses the given event (E.G: "MESSAGE PUBLIC"),
# calls the trigger finder thing with the message, does
# other crap, etc.
# Free cookies to anyone with a good name for this.  Better
# won't cut it, needs to be a good name to get the prize.
# It returns whatever the trigger's code does, so error
# checking or trapping is done by whatever called "gazelle".
# Note: Cycles are cheap.
sub gazelle {
  my $self = shift;

  $self->[7] or
    warn, croak 'Module must be initialized before further use ';

  my @data = $self->[0]->{$self->[1]}->(@_);

  @data > 0 or
    warn, croak 'Unabled to parse given event ';

  my ($message, $nick, $address, $target, $server) = @data;
  undef(@data);

  defined($target) and # if $target is defined we need to check it; otherwise, it must be a private message to me and the trigger should deal with it
    (_check_channel($target, @{$self->[3]}) or
      return (undef));

  my @trig = _find_trigger($message, %{$self->[2]});

  not @trig and
    return (undef);
  @trig > 1 and
    warn, croak "Multiple matches found  for '$data[0]', please check your regexes ";

  my ($t, $m, $d) = @{$trig[0]};

  return ($self->[2]->{$t}->($m, $d, $nick, $address, $target, $server));
}

# Initializes the module, basically a lazy (and faster) way
# to make sure that everything is in order before we start
# parsing.  Ike ike go go, JUMP!
sub ike {
  my $self = shift;

  $self->[7] and
    warn, croak 'BAKA ' x 150;

  keys %{$self->[2]} > 0 or
    warn, croak 'Unabled to initialized, no triggers registered ';

  (exists($self->[0]->{$self->[1]}) and
    ref($self->[0]->{$self->[1]}) eq 'CODE') or
      warn, croak 'Selected method is invalid ';

  foreach my $t (keys %{$self->[2]}) {
    ref($self->[2]->{$t}) eq 'CODE' or
      warn, croak "Trigger '$t' is invalid, cannot initialize ";
  }

  $self->[7] = 1;
}

sub register {
  my $self = shift;

  $self->[5] and
    warn, croak 'Cannot call "register" twice ';
  $self->[6] and
    warn, croak 'Cannot call "register", "unregister" was called already ';

  $self->[5] = 1;

  return ($self);
}

sub unregister {
  my $self = shift;

  $self->[6] and
    warn, croak 'Cannot call "unregister" twice ';
  $self->[5] and
    warn, croak 'Cannot call "unregister", "register" was called already ';

  $self->[6] = 1;

  return ($self);
}

sub trigger { # $t->register->trigger(\%mytrig)
  my $self = shift;
  my ($trigs) = @_;

  ($self->[5] and
    $self->[6]) and
      confess;

  if ($self->[5]) {
    ref($trigs) eq 'HASH' or
      warn, croak 'Malformed "register trigger" call ';

    $self->[5] = 0;

    foreach my $t (keys %{$trigs}) {
      (exists($self->[2]->{$t}) and
        not $self->[4]) and
          warn, croak "Unabled to register trigger '$t', overloading not enabled ";

      ref($trigs->{$t}) eq 'CODE' or
        warn, croak "Unabled to register trigger '$t', invalid reference ";

      $self->[2]->{$t} = $trigs->{$t};
    }
  } elsif ($self->[6]) {
    ref($trigs) and
      warn, croak 'Malformed "unregister trigger" call ';

    $self->[6] = 0;

    _delete_key_by_regex($trigs, $self->[2]) or
      warn, croak "Unabled to delete trigger matching '$trigs' ";
  } else {
    warn, croak 'Cannot call "trigger" without a prior call to "register" or "unregister" ';
  }
}

sub parser { # $t->unregister->parser('PASSTHROUGH')
  my $self = shift;
  my ($pars) = @_;

  ($self->[5] and
    $self->[6]) and
      confess;

  if ($self->[5]) {
    ref($pars) eq 'HASH' or
      warn, croak 'Malformed "register parser" call ';
    $self->[5] = 0;

    foreach my $p (keys %{$pars}) {
      (exists($self->[0]->{$p}) and
        not $self->[4]) and
          warn, croak "Unabled to register parser '$p', overloading not enabled ";

      ref($pars->{$p}) eq 'CODE' or
        warn, croak "Unabled to register parser '$p', invalid reference ";

      $self->[0]->{$p} = $pars->{$p};
    }
  } elsif ($self->[6]) {
    ref($pars) and
      warn, croak 'Malformed "unregister parser" call ';
    $self->[6] = 0;

    _delete_key_by_regex($pars, $self->[0]) or
      warn, croak "Unabled to delete parser matching '$pars' ";
  } else {
    warn, croak 'Cannot call "parser" without a prior call to "register" or "unregister" ';
  }
}



# Internal subroutines.

sub _find_trigger ($\%) {
  my ($message, $t) = @_;
  my @match;

  length($message) or
    return (undef);

  foreach my $r (keys %{$t}) {
    $message =~ /^\s*($r)(?:\b\s*(.*))\s*$/ and do {
      if (length($2)) {
        push(@match, [$r, $1, $2]);
      } else {
        push(@match, [$r, $1, undef]);
      }
    };
  }

  return (@match);
}

sub _delete_key_by_regex ($$) {
  my ($r, $h) = @_;
  my $match = 0;

  (defined($r) and
    ref($h) eq 'HASH') or
      confess;

  foreach my $k (grep /$r/o, keys %{$h}) {
    delete($h->{$k}) or
      return (undef);
    $match++;
  }

  return ($match);
}

sub _delete_element_by_regex ($$$) {
  my ($r, $a, $e) = @_;
  my $match = 0;

  (defined($r) and
    ref($a) eq 'ARRAY') or
      confess;

  for (my $i = @{$a}; $i--; ) {
    $a->[$i] =~ /$r/o and do {
      delete($a->[$i]) or
        return (undef);
      $match++;
    };
  }

  $e and
    @{$a} = grep { defined } @{$a};

  return ($match);
}

sub _find_target ($) {
  my ($target) = @_;

  $target =~ /^(?:&|#)/o and
    return ($target);

  return (undef);
}

sub _check_channel ($\@) {
  my ($channel, $l) = @_;

  foreach my $c (@{$l}) {
    $channel =~ /$c/ and
      return ($c);
  }

  return (undef);
}

'True!';