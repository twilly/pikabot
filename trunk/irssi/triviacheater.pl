# triviacheater.pl: irssi triva bot cheater
#
# Copyright (C) 2006   Tristan Willy <tristan.willy at gmail.com>
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
use Time::HiRes qw(sleep);
use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'Trivia Cheater',
           'description' => 'Listens for triva bots and answers what it can.',
           'license'     => 'GPL v2' );

my %questions;
my ($Qstate, $dirty) = (undef, 0);

load_questions();

Irssi::timeout_add(60*1000, 'save_questions', undef);
Irssi::signal_add('event privmsg', 'irc_privmsg');

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  strip_color(\$message);

  if($message =~ /NMA\.(\d+)\.\s*(.+)/o){
    my ($num, $Q) = ($1, $2);
    Irssi::print("trivia cheater: picked up Q $num: $Q");
    $Qstate = $Q;
    if(defined $questions{$Q} and
       $num eq $questions{$Q}{number} and
       defined $questions{$Q}{answer}){
      #sleep(1.5);
      $server->command("msg $to Here's the answer: $questions{$Q}{answer}");
    } else {
      $questions{$Q}{number} = $num;
      $questions{$Q}{answer} = undef;
    }
  }

  if($message =~ /.*answer.*->\s+(.+?)\s+<-/o and
     $message =! /last question/){
    my $ans = $1;
    Irssi::print("trivia cheater: answer: $ans");
    if(defined $Qstate and
       defined $questions{$Qstate}{number}){
      $questions{$Qstate}{answer} = $ans;
      $dirty = 1;
    }
  }

  return 1;
}

sub load_questions {
  open(QFILE, "$ENV{HOME}/.irssi/trivia.txt")
    or do { 
      Irssi::print("trivia cheater: unable to open the trivia questions file.");
      return 1;
    };
  while(<QFILE>){
    chomp;
    my @quest = split(/<delim>/);
    $questions{$quest[1]}{number} = $quest[0];
    $questions{$quest[1]}{answer} = $quest[2];
  }
  close(QFILE);
  return 0;
}

sub save_questions {
  if($dirty){
    my $count = 0;
    $dirty = 0; # clear even if failure
    open(QFILE, ">$ENV{HOME}/.irssi/trivia.txt")
      or do {
        Irssi::print("trivia cheater: unable to save questions file.");
        return 1;
      };
    foreach my $Q (keys %questions){
      if(defined $questions{$Q}{answer}){
        print QFILE "$questions{$Q}{number}<delim>$Q<delim>$questions{$Q}{answer}\n";
        $count++;
      }
    }
    close(QFILE);
    Irssi::print("trivia cheater: saved $count qustions");
  }
  return 1;
}

sub strip_color {
  my $text = shift;
  $$text =~ s/(\x02)|(\x1f)//g;
  $$text =~ s/\x03(01)./ /g;
  $$text =~ s/\x03([01])?[0-9](,([01])?[0-9])?//g;
  $$text =~ s/\xa0/ /g;
}
