# Scrape.pm: HTML Screen-scraper engine.
#
# Copyright (C) 2008-2009 Tristan Willy <tristan.willy at gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

HTML::Scrape - HTML state machine scrapper.

=head1 SYNOPSIS

  use HTML::Scrape qw(put);

  my $scraper = new HTML::Scrape(
    Machine => [ { 'tag' => 'td' },
                 { 'text' => put('tdata') }
               ]) or die;

  print "$_\n" foreach ($scraper->scrape_file("file.html"));

=head1 DESCRIPTION

Scrape HTML documents quickly using a state machine, and without using
the slow HTML parser L<HTML::TreeBuilder>.

=head1 METHODS

=over

=cut

package HTML::Scrape;
require Exporter;
use HTML::Parser;
@ISA = qw(Exporter HTML::Parser);
@EXPORT_OK = qw(scrape reset put);

use strict;
use warnings;
use Carp;
use Data::Dumper;
use HTML::Entities;

=item $s = new HTML::Scrape(Machine => [ ... ]);

Make a new HTML::Scrape object. Machine points to the machine description.

=cut

sub start_handler () { apply_state(\&tag_insn, @_) }
sub text_handler  () { apply_state(\&text_insn, @_) }
sub end_handler   () { apply_state(\&tag_end_insn, @_) }

sub new {
  my $type = shift;
  my $self = {};
  my %args = @_;

  # only call if $state_obj is a tag check
  my $handlers =
    { start => [ \&start_handler, 'event, self, tagname, attr' ],
      text  => [ \&text_handler, 'event, self, text' ],
      end   => [ \&end_handler, 'event, self, tagname' ] 
    };
  $self = $type->HTML::Parser::new(api_version => 3,
                                   handlers => $handlers);
  $self->unbroken_text(1); 

  $self->{states} = $args{Machine} or return;
  $self->{trace} = 0;
  $self->{decents} = 1;
  $self->{labels} = mklabellookup(@{$self->{states}});

  $self->reset();

  return bless $self, $type;
}

=item $s->trace() or $s->trace($arg)

Set/get trace flag. This is helpful when debugging the state machine.

=cut

sub trace {
  my ($self, $flag) = @_;
  $self->{trace} = $flag if defined $flag;
  return $self->{trace};
}

=item $s->decode() or $s->decode($arg)

Set/get decode flag. If set, HTML entities are decoded on text segments.

Default: decode HTML entities

=cut

sub decode {
  my ($self, $flag) = @_;
  $self->{decents} = $flag if defined $flag;
  return $self->{decents};
}

sub debug {
  my ($self, $text, $items) = @_;

  print STDERR sprintf("%2d: $text", $self->{state});
  if($items){
    print STDERR ", ";
  } else {
    print STDERR " ";
  }
  my $dumper = new Data::Dumper([$items]);
  $dumper->Indent(0);
  $dumper->Varname("items");
  print STDERR $dumper->Dump();
  print STDERR "\n";
}

sub mklabellookup {
  my $labels = {};
  my $i = 0;
  foreach (@_){
    if(ref eq 'HASH'){
      $labels->{$_->{label}} = $i if $_->{label};
    } else {
      foreach (@{$_}){
        $labels->{$_->{label}} = $i if $_->{label};
      }
    }
    $i++;
  }
  return $labels;
}

=item $s->reset()

Reset the state machine. This is useful when parsing sets of strings with a
single object.

This is implicitly called before scrapping when scrapping whole files.

=cut

sub reset {
  my ($self) = @_;
  $self->{state} = 0;
  $self->{capture_text} = 0;
  $self->{element} = {};
  $self->{results} = [];
  $self->{endtag} = ''; 
}

=item @data = $s->scrape(string [, reset])

Scrape a file or string. The machine is *not* reset, unless reset is specified
and true.

@data contains elements saved with HTML::Scrape::put()

=cut

sub scrape {
  my ($self, $item, $reset_flag) = @_;

  
  $self->reset() if $reset_flag;
  $self->{results} = [];
  $self->SUPER::parse($item);
  return @{$self->{results}};
}

=item @data = $s->scrape_file(filename/filehandle [, reset])

Scrape a file. The machine is reset before scrapping, unless reset is
specified and false.

@data contains elements saved with HTML::Scrape::put()

=cut

sub scrape_file {
  my ($self, $item, $reset_flag) = @_;
  $reset_flag = defined $reset_flag ? $reset_flag : 1;

  $self->reset() if $reset_flag;
  $self->SUPER::parse_file($item);
  return @{$self->{results}};
}

# print %{$result}
# called by the state machine interpreter
sub commit_result {
  my ($self) = @_;
  push @{$self->{results}}, $self->{element};
  $self->{element} = {};
}

=item HTML::Scrape::put($name)

Returns a callback that stores data into an element with $name.

=cut

sub put {
  my ($kind) = @_;
  return sub {
    my ($self, $val) = @_;
    # Stuff $val into the current element.
    # If there's a collision, convert/put into an array.
    my $el = $self->{element};
    if(ref $el->{$kind} eq 'ARRAY'){
      push @{$el->{$kind}}, $val;
    } else {  
      if(defined $el->{$kind}){
        $el->{$kind} = [ $el->{$kind}, $val ];
       } else {
         $el->{$kind} = $val;
       }
    }
  }
}

# increment the state, and commit our data if we rolled over
sub next_state {
  my ($self, $state_obj) = @_;

  my $old_state_obj = $state_obj;
  my $should_commit = 0;
  $should_commit = 1 if $state_obj->{commit};

  # State with a goto -> immediate jump
  if(defined $state_obj->{'goto'}){
    if(defined $self->{labels}{$state_obj->{'goto'}}){
      $self->{state} = $self->{labels}{$state_obj->{'goto'}};
    } else {
      confess "State $self->{state} is a goto, but there is no " .
        "state with label \"$state_obj->{'goto'}\"\n";
    }
  } else {
    # move to default next state
    $self->{state} = ($self->{state} + 1) % ($#{$self->{states}} + 1);

    # if we loop back to the top, commit
    $should_commit = 1 if $self->{state} == 0;
  }

  commit_result($self) if $should_commit;

  debug($self, "Moved to new state") if $self->{trace};
}

# applies a function to multiple state objects, or just one
# note: %keytest is there to avoid calling $fn too often -> 20% speedup.
sub apply_state {
  my $fn = shift;
  my $event = shift;
  my ($self) = @_;
  my %keytest = ( start => 'tag', text => 'text' );
  my $state_obj = $self->{states}->[$self->{state}];

  debug($self, "Event $event", $state_obj) if $self->{trace};
  if(ref($state_obj) eq 'ARRAY'){
    foreach my $so (@{$state_obj}){
      if(not $keytest{$event} or
         defined $so->{$keytest{$event}}){
        last if $fn->(@_, $so);
      }
    }
  } else {
    if(not $keytest{$event} or
       defined $state_obj->{$keytest{$event}}){
      $fn->(@_, $state_obj);
    }
  }
} 

sub tag_insn {
  my ($self, $tag, $attr, $state_obj) = @_;

  return 0 if not defined $state_obj->{tag};

  debug($self, "<$tag>", { $attr, $state_obj->{tag} }) if $self->{trace};

  # match against a tag
  my $tag_match = 0;
  if(ref $state_obj->{tag} eq 'Regexp' and
     $tag =~ $state_obj->{tag}){
    $tag_match = 1;
  } elsif($tag eq lc($state_obj->{tag})){
    $tag_match = 1;
  }

  my $hit = 0;
  my $exclude_hit = 0;
  if($tag_match){
    # tag matched. match everything else
    foreach my $m_attr (keys %{$state_obj->{require}}){
      # regex match
      if(ref $state_obj->{require}{$m_attr} eq 'Regexp' and
         defined $attr->{$m_attr} and
         $attr->{$m_attr} =~ $state_obj->{require}{$m_attr}){
        $hit++;
      }

      # string match (case insensitive)
      if(not ref $state_obj->{require}{$m_attr} and
         defined $attr->{$m_attr} and
         lc($attr->{$m_attr}) eq lc($state_obj->{require}{$m_attr})){
        $hit++;
      }
    }

    # exclude rules
    foreach my $m_attr (keys %{$state_obj->{exclude}}){
      if(ref $state_obj->{exclude}{$m_attr} eq 'Regexp' and
         defined $attr->{$m_attr} and
         $attr->{$m_attr} =~ $state_obj->{exclude}{$m_attr}){
        $exclude_hit++;
      }
      if(not ref $state_obj->{exclude}{$m_attr} and
         defined $attr->{$m_attr} and
         lc($attr->{$m_attr}) eq lc($state_obj->{exclude}{$m_attr})){
        $exclude_hit++;
      }
    }
  }

  # $hit should be number of keys in the state hash minus the tag key
  my $should_hit = keys %{$state_obj->{require}};
  if($tag_match and
     not $exclude_hit and
     $hit == $should_hit){
    $self->{endtag} = $tag;
    $self->{capture_text} = 1;

    # see if any attributes should be recalled
    if(defined $state_obj->{attr}){
      foreach my $wanted_attr (keys %{$state_obj->{attr}}){
        if(defined $attr->{$wanted_attr} and
           ref($state_obj->{attr}{$wanted_attr}) eq 'CODE'){
          $state_obj->{attr}{$wanted_attr}->($self, $attr->{$wanted_attr});
        }
      }
    }

    next_state($self, $state_obj);
    return 1;
  }

  return 0;
}

sub tag_end_insn {
  my ($self, $tag, $state_obj) = @_;

  # halt capture after the end of the last matched tag
  if($tag eq $self->{endtag}){
    # stop capturing text
    $self->{capture_text} = 0;

    # parse for matching end tag
    if(defined $state_obj->{tag} and $state_obj->{tag} =~ /^\//){
        my %tmpobj = %{$state_obj};
        $tmpobj{tag} =~ s/^\///;
        $self->tag_insn($tag, {}, \%tmpobj);
    }

    # now, if we ended the tag, and are trying to capture text,
    # register nothing into our capture
    if(defined $state_obj->{text}){
      my $key = $state_obj->{text};
      if(ref $key eq 'CODE'){
        $key->(undef);
        next_state($self, $state_obj);
        return 1;
      } elsif(ref $key eq 'Regexp' and
              '' =~ $key){
        next_state($self, $state_obj);
        return 1;
      }
    }
  }

  return 0;
}

sub text_insn {
  my ($self, $text, $state_obj) = @_;

  return 0 if not defined $state_obj->{text};

  if($self->{decents}){
    $text = HTML::Entities::decode_entities($text);
  }

  if($self->{trace}){
    my $ptext = $text;
    $ptext =~ s/\n/\\n/g;
    debug($self, "\"$ptext\"");
  }

  # Only capture text between the tags of a last matched tag
  # and only if there is some text passed in.
  if(not $self->{capture_text} or 
     $text =~ /^\s*$/){
    return 0;
  }

  # if we're looking for text, get it, stuff it, and go to the next state
  my $mtxt = $state_obj->{text};
  if(defined $mtxt){
    if(ref $mtxt eq 'CODE'){
      $mtxt->($self, $text);
      next_state($self, $state_obj);
      return 1;
    } elsif(ref $mtxt eq 'Regexp' and
            $text =~ $mtxt){
      next_state($self, $state_obj);
      return 1;
    }
  }
}

=back

=head1 STATEMACHINE

The state machine is built by passing in an array reference containing the
states. Each state is described by a hash reference or an array of hash
references. The hash reference hold the state instruction, such as matching
a tag or storing text. If a state is a array reference, multiple state
instructions are evaluated in array order (as if there were shift()ed out).

On initialization, the machine is set to the first state. Moving from one
state to another is done by use of the default move to the next defined state
or by use of a 'goto' statement.

Data is scrapped by calling a function with data to be entered. A utility
function, C<put>, is included in this module. It'll return an anonymous
function that'll load up a hash with an supplied key. Multiple entries
are converted from a scalar into an array.

The state machine will loop from the last state to the first state by default.
When this occurs, any data entered by C<put> is commited and future calls to
functions returned by C<put> will work on a clean slate. A commit instruction
is available to force early commits.

=head2 Instructions

=head3 tag

Matches a HTML tag. This may be a string or a regular expression reference.

  { 'tag' => 'a' }
  { 'tag' => qr/div|span/ }

=head4 require

Matches attributes on tag instructions. Formed by a hash reference to all
desired attributes. Each attribute can be matched by a string or regex
reference.

  { 'tag' => 'a',
    'require' =>
      { 'href' => qr/slashdot\.org/ } }

=head4 exclude

Same as 'require' but exlusionary. Any exclude attribute match hits will
override a successful 'require'.

 { 'tag' => 'a'
   'exclude' =>
    { 'href' => qr/digg\.com/ } }

=head4 attr

Call a function with the requested attribute value.

 { 'tag' => 'a'
   'attr' => { 'href' => put('link'),
               'alt'  => put('alt')  } }

=head3 text

Match text or call a function with text. Matching is done by a regex
reference. If the value is a code reference, it is called.

  { 'text' => put('location') }
  { 'text' => qr/Search results/ }

=head3 label

Assigns a state position a label.

  { 'label' => 'link',
    'tag' => 'a' }

=head3 goto

Instead of advancing to the next state, advance to a labeled state.

  { 'tag' => 'span',
    'goto' => 'link' }

=head3 commit

Save any data stored by C<put> and give it a clean hash. Stored data is
returned by C<scrape> and C<scrape_file>.

  { 'tag' => 'span',
    'goto' => 'link',
    'commit' => 1 }

=head1 SEE ALSO

L<HTML::Parser>

=head1 COPYRIGHT

  Copyright 2008 Tristan Willy. All rights reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

1;
