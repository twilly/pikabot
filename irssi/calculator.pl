#!/usr/bin/env perl

use strict;
use Text::ParseWords;
use Math::Trig;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = '0.01';
%IRSSI = ( 'authors'     => 'Tristan Willy',
           'contact'     => 'tristan.willy at gmail.com',
           'name'        => 'calculator',
           'description' => 'A infix and RPN calculator',
           'license'     => 'GPL v2' );

# error messages go here
my $error;
# operator information for the shunting algorithm to use
my %operators = ( '+' => { 'assoc' => 'left',  'prec' => 1 },
                  '-' => { 'assoc' => 'left',  'prec' => 1 },
                  '*' => { 'assoc' => 'left',  'prec' => 2 },
                  '/' => { 'assoc' => 'left',  'prec' => 2 },
                  '%' => { 'assoc' => 'left',  'prec' => 2 },
                  '^' => { 'assoc' => 'right', 'prec' => 3 }
                );
# operators, constants, and functions are all just functions :)
my %functions = ( '+' => sub { calc_binop(sub { return $_[0] + $_[1] }, @_) },
                  '-' => sub { calc_binop(sub { return $_[0] - $_[1] }, @_) },
                  '*' => sub { calc_binop(sub { return $_[0] * $_[1] }, @_) },
                  '/' => sub { calc_binop(sub { return $_[0] / $_[1] }, @_) },
                  '%' => sub { calc_binop(sub { return $_[0] % $_[1] }, @_) },
                  '^' => sub { calc_binop(sub { return $_[0] ** $_[1] }, @_) },
                  'e' => \&calc_const,
                  'pi' => \&calc_const,
                );
my %trig = ( 'csc' => sub { return csc($_[0]) },
             'cosec' => sub { return cosec($_[0]) },
             'sec' => sub { return sec($_[0]) },
             'cotan' => sub { return cotan($_[0]) },
             'sin' => sub { return sin($_[0]) },
             'cos' => sub { return cos($_[0]) },
             'tan' => sub { return tan($_[0]) },
             'asin' => sub { return asin($_[0]) },
             'acos' => sub { return acos($_[0]) },
             'atan' => sub { return atan($_[0]) },
             'acsc' => sub { return acsc($_[0]) },
             'cot' => sub { return cot($_[0]) },
             'acosec' => sub { return acosec($_[0]) },
             'asec' => sub { return asec($_[0]) },
             'acot' => sub { return acot($_[0]) },
             'acotan' => sub { return acotan($_[0]) },
             'degtorad' => sub { return deg2rad($_[0]) },
             'radtodeg' => sub { return rad2deg($_[0]) },
            );
map { $functions{$_} = \&calc_trig } keys %trig;

my (%active_chans, $debug);

Irssi::settings_add_str($IRSSI{name}, "$IRSSI{name}_channels", '');
Irssi::settings_add_bool($IRSSI{name}, "$IRSSI{name}_debug", 'off');
load_globals();
Irssi::signal_add('event privmsg', 'irc_privmsg');
Irssi::signal_add('setup changed', 'load_globals');

sub load_globals {
  map { $active_chans{uc($_)} = 1 }
    quotewords(',', 0, Irssi::settings_get_str("$IRSSI{name}_channels"));
  $debug = Irssi::settings_get_bool("$IRSSI{name}_debug");
}

sub irc_privmsg {
  my ($server, $data, $from, $address) = @_;
  my ($to, $message) = split(/\s+:/, $data, 2);
  my ($me, $target) = ($server->{'nick'}, find_target($to, $from));

  # clear any old errors
  $error = 'unknown error';

  if(uc($to) eq uc($me) or $active_chans{uc($to)}){
    if($message =~ /^[^!@]*!calc(ulat(e|or))?\s+(.+)/oi){
      my $input = $3;
      my $rpn = shunting($input);
      if(not defined $rpn){
        $server->command("msg $target \x0304Parsing error: $error");
        return;
      }
      if($debug){
        my @syms;
        map { push @syms, $_->[1] } @{$rpn};
        Irssi::print("$IRSSI{name}: infix->rpn: $input => @syms");
      }
      eval { # protect against calculation errors
        my $answer = execute_rpn($rpn);
        if(not defined $answer){
          $server->command("msg $target \x0304Execution error: $error");
          return;
        }
        $server->command("msg $target $input = $answer");
      };
      if($@){
        $server->command("msg $target \x0304Fatal error: $@");
      }
    }
  } 
}

sub execute_rpn {
  my $rpn = shift;
  my @stack;
  while($#{$rpn} >= 0){
    my $sym = shift @{$rpn};
    if($sym->[0] eq 'NUMBER'){
      push @stack, $sym;
      next;
    }
    if($sym->[0] eq 'STRING' and
       not defined $functions{$sym->[1]}){
      $error = "undefined function '$sym->[1]'.";
      return undef;
    } else {
      $functions{$sym->[1]}->($sym, \@stack);
      next;
    }
    $error = "unknown RPN symbol type $sym->[0]: $sym->[1]";
    return undef;
  }
  if($#stack != 0){
    $error = "RPN error: stack doesn't have exactly one element";
    return undef;
  } else {
    return $stack[0]->[1];
  }
}

sub shunting {
  my (@out, @opstack);

  my $tokens_ref = get_tokens(shift) or return;
  my @tokens = @{$tokens_ref};
  my $lh_token = shift @tokens;
  while($lh_token->[0] ne 'EOE'){
    # current token is the next token. if there are no more tokens in the
    # queue, set lookahead to End Of Equasion
    my $token = $lh_token;
    if($#tokens >= 0){
      $lh_token = shift @tokens;
    } else {
      $lh_token = [ 'EOE', undef ];
    }

    if($token->[0] eq 'NUMBER'){
      push @out, $token;
      next;
    }
    if($token->[0] eq 'OPERATOR'){
      # pop off operators into the output queue if they have better
      # associativity and precedence than the current operator.
      while($#opstack >= 0 and 
            defined $operators{$token->[1]} and
      	    defined $operators{$opstack[$#opstack]->[1]} and
            ( ( $operators{$token->[1]}{assoc} eq 'left' and 
                $operators{$token->[1]}{prec} <= $operators{$opstack[$#opstack]->[1]}{prec} ) or
              ( $operators{$token->[1]}{assoc} eq 'right' and 
                $operators{$token->[1]}{prec} < $operators{$opstack[$#opstack]->[1]}{prec} ))){
        push @out, pop @opstack;
      }
      push @opstack, $token;
      next;
    }
    if($token->[0] eq 'LEFT_PAREN'){
     push @opstack, $token;
     next;
    }
    if($token->[0] eq 'RIGHT_PAREN'){
      # pop everything out until a left parentheses
      while($#opstack >= 0 and $opstack[$#opstack]->[1] ne '('){
        push @out, pop @opstack;
      }
      if($#opstack < 0){
        $error = "mismatched parenthesess";
        return undef;
      }
      pop @opstack; # take out left parentheses
      
      # if the top of the stack is a function (aka: string), pop it out too
      if($#opstack >= 0 and $opstack[$#opstack]->[0] eq 'STRING'){
        push @out, pop @opstack;
      }
      next;
    }
    if($token->[0] eq 'STRING'){
      push @opstack, $token;

      # implicitly generate functions
      if($lh_token->[0] ne 'LEFT_PAREN'){
        # put back the lookahead
        unshift @tokens, $lh_token;
        # shove in parenthesess
        unshift @tokens, [ 'RIGHT_PAREN', ')' ];
        $lh_token = [ 'LEFT_PAREN', '(' ];
      }
      next;
    }
    if($token->[0] eq 'COMMA'){
      while($#opstack >= 0 and $opstack[$#opstack]->[0] ne 'LEFT_PAREN'){
        push @out, @opstack;
      }
      if($#opstack < 0){
        $error = "mismatched parentheses or misplaced comma";
        return undef;
      }
      next;
    }
    
    $error = "Unknown token `$token->[0]'";
    return undef;
  }

  # empty the operator stack
  while($#opstack >= 0){
    if($opstack[$#opstack]->[0] eq 'LEFT_PAREN'){
      $error = "mismatched parentheses";
      return undef;
    }
    push @out, pop @opstack;
  }

  return \@out;
}

sub get_tokens {
  my $str = shift;
  my @tokens;

  while(length $str > 0){
    if($str =~ s/^((\d*)\.(\d+)|(\d+)\.?\d*)//o){
      push @tokens, [ 'NUMBER', $1 ];
      next;
    } 
    if ($str =~ s/^(\+|\-|\/|\*|\%|\^)//o){
      push @tokens, [ 'OPERATOR', $1 ];
      next;
    }
    if($str =~ s/^\(//o){
      push @tokens, [ 'LEFT_PAREN', '(' ];
      next;
    }
    if($str =~ s/^\)//o){
      push @tokens, [ 'RIGHT_PAREN', ')' ];
      next;
    }
    if($str =~ s/^([a-z]+)//io){
      push @tokens, [ 'STRING', $1 ];
      next;
    }
    if($str =~ s/^,//o){
      push @tokens, [ 'COMMA', $1 ];
      next;
    }
    if($str =~ s/\s|\n//o){
      next; # whitespace
    }
    if($str =~ s/^(.)//o){
      $error = "unmatched character `$1'";
      return undef;
    }
  }

  return \@tokens;
}

# generic binary operator
sub calc_binop {
  my ($op, $sym, $stack) = @_;
  my $right = pop @{$stack};
  my $left  = pop @{$stack};
  if($right->[0] ne 'NUMBER' or
     $left->[0] ne 'NUMBER'){
    $error = "binary operator called with non-number arguments";
    push @{$stack}, [ 'ERROR', 'ERROR' ];
    return;
  }
  push @{$stack}, [ 'NUMBER', $op->($left ->[1], $right->[1]) ];
}

# constants
sub calc_const {
  my ($sym, $stack) = @_;
  my %constants = ( 'e' => 2.71828183,
                    'pi' => 3.14159265,
                  );
  if(not defined $constants{$sym->[1]}){
    $error = "unknown constant $sym->[1]";
    push @{$stack}, [ 'ERROR', 'ERROR' ];
    return;
  }
  
  push @{$stack}, [ 'NUMBER', $constants{$sym->[1]} ];
} 

sub calc_trig {
  my ($sym, $stack) = @_;
  my $num = pop @{$stack};
  if(not defined $num or $num->[0] ne 'NUMBER'){
    $error = "missing argument for function $sym->[1]";
    push @{$stack}, [ 'ERROR', 'ERROR' ];
    return;
  }
  push @{$stack}, [ 'NUMBER', $trig{$sym->[1]}->($num->[1]) ];
}

sub find_target {
  my ($to, $from) = @_;

  if($to =~ /^#/){
    return $to; # from a channel
  }
  return $from; # from a private message
}

