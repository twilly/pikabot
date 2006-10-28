# wb.pl: Welcome Back script

use strict;
use Text::ParseWords;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'WB',
           'description' => 'Welcome back script',
           'license'     => 'GPL v2' );

Irssi::settings_add_str($IRSSI{'name'}, 'wb_channels', '');
Irssi::settings_add_str($IRSSI{'name'}, 'wb_config', "$ENV{HOME}/.irssi/wb.conf");
Irssi::command_bind('wb', 'cmd_wb');

my %active_chans;
my %wb_messages;
load_globals();

Irssi::signal_add('message join', 'irc_onjoin');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str('wb_channels'));
  load_config();
}

sub load_config {
  %wb_messages = ();
  my $file = Irssi::settings_get_str('wb_config');
  if(open(CFH, $file)){
    while(<CFH>){  # cookbook
      chomp;
      s/#.*//;
      s/^\s+//;
      s/\s+$//;
      next unless length;
      my ($lv, $rv) = split(/\s*=\s*/, $_, 2);
      push @{$wb_messages{$lv}}, $rv; # config only holds WBs
    }
    close CFH;
  } else {
    Irssi::print("$IRSSI{name}: Warning: Unable to open config: $!");
  }
}

sub save_config {
  my $file = Irssi::settings_get_str('wb_config');
  if(open(CFH, ">$file")){
    map {
      foreach my $wb (@{$wb_messages{$_}}){
        print CFH "$_ = $wb\n";
      }
    } sort keys %wb_messages;
    close CFH;
  } else {
    Irssi::print("$IRSSI{name}: Warning: Unable to open config: $!");
  }
}

sub cmd_wb {
  my ($data, $server, $witem) = @_;
  my %cmd_wb_handlers =
    ( 'ADD' => \&cmd_wb_add,
      'RM' => \&cmd_wb_rm,
      'DEL' => \&cmd_wb_rm,
      'LS' => \&cmd_wb_ls,
      'LIST' => \&cmd_wb_ls,
      'ALIAS' => \&cmd_wb_alias,
      'RLD' => \&load_config,
      'HELP' => \&cmd_wb_help );

  if($data =~ /^\s*(\S+)(\s+(.+))?/){
    my ($cmd, $args) = (uc($1), $3);
    if(defined $cmd_wb_handlers{$cmd}){
      $cmd_wb_handlers{$cmd}->($server, $witem, $args);
    } else {
      Irssi::print("$IRSSI{name}: Warning: Unknown command `$cmd'. See `/WB HELP'.");
    }
  } else {
    Irssi::print("$IRSSI{name}: Warning: Malformed /WB command. See `/WB HELP'.");
  }
}

sub cmd_wb_add {
  my ($server, $witem, $args) = @_;
  if($args =~ /(\S+)\s+(.+)/){
    my ($nick, $wb) = ($1, $2);
    push @{$wb_messages{$nick}}, $wb;
    save_config();
    Irssi::print("$IRSSI{name}: Added WB for $nick");
  } else {
    Irssi::print("$IRSSI{name}: Error: Malformed ADD command.");
  }
}

sub cmd_wb_rm {
  my ($server, $witem, $args) = @_;
  if($args =~ /(\S+)\s+(.+)/){
    my ($nick, $match) = ($1, $2);
    if(defined $wb_messages{$nick}){
      my @new_set;
      my $has_deleted = 0;
      foreach my $message (@{$wb_messages{$nick}}){
        if($message !~ /$match/){
          push @new_set, $message;
        } else {
          $has_deleted = 1;
          Irssi::print("$IRSSI{name}: Deleted WB for $nick: $message");
        }
      }
      if($has_deleted){
        $wb_messages{$nick} = \@new_set;
        save_config();
      }
    } else {
      Irssi::print("$IRSSI{name}: No messages for $nick.");
    }
  } else {
    Irssi::print("$IRSSI{name}: Malformed RM command.");
  }
}

sub cmd_wb_ls {
  my ($server, $witem, $args) = @_;
  Irssi::print(" [ Welcome Backs ] ");
  map {
    foreach my $wb (@{$wb_messages{$_}}){
      Irssi::print("($_) $wb");
    }
  } sort keys %wb_messages;
}

sub cmd_wb_alias {
  my ($server, $witem, $args) = @_;
  Irssi::print("$IRSSI{name}: Alias is currently unimplemented.");
}

sub cmd_wb_help {
  my ($server, $witem, $args) = @_;
  my %detailed =
    ( 'ADD' => "Add a message: ADD <nick> <message>",
      'RM' => "Remove a message: RM <nick> <message regex>",
      'LS' => "List messages: LS",
      'ALIAS' => "Create a nick alias: ALIAS <nick alias> <nick target>",
      'RLD' => "Reload WBs from config: RLD"
    );

  if(length $args){
    $args =~ s/^\s+//;
    $args =~ s/\s+$//;
    if(defined $detailed{uc($args)}){
      map { Irssi::print($_) } split /\n/, $detailed{uc($args)};
    } else {
      Irssi::print("No detailed help for command `$args'");
    }
  } else {
    Irssi::print("$IRSSI{name}: A \"welcome back\" script.");
    Irssi::print("Commands: ADD, RM, LS, RLD, ALIAS, HELP");
    Irssi::print("Use `/WB HELP <command>' for more information.");
  }
}

sub irc_onjoin {
  my ($server, $channel, $nick, $address) = @_;

  # Check if it was for the channel we joined...
  if($active_chans{uc($channel)} and defined $wb_messages{$nick}){
    $server->command("msg $channel *WB($nick)WB* " . get_wb($nick));
  }

  return 1;
}

# gets a message from the wb
# acts like a shift register ring
sub get_wb {
  my $nick = shift;
  my $msg = undef;
  if(defined $wb_messages{$nick}){
    $msg = shift @{$wb_messages{$nick}};
    push @{$wb_messages{$nick}}, $msg;
  }
  return $msg;
}
