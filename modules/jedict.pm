# jedict.pm: japanese <-> english dictionary module
# Copyright (C) 2006   Andreas Högström <superjojo at gmail.com>
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

package jedict;

use strict;
use Encode;
use DBI;

sub new {
	my $type = shift;
	my %params = @_;
	my $self = {};
	if(not defined $params{Database}){
		return undef;
	}

	# set optional paramaters
	map {
		$params{$_} = exists $params{$_} ?  $params{$_} : undef;
	} ('Username', 'Password', 'Server');

	my $connect_str = "dbi:Pg:dbname=$params{Database}";
	$connect_str .= ";host=$params{Server}" if defined $params{Server};
	$self->{dbh} = DBI->connect($connect_str,$params{Username}, $params{Password},{ RaiseError => 1, PrintError => 0,AutoCommit => 0 }) or return undef;

	$params{'Schema'} = exists $params{'Schema'} ? $params{'Schema'} : 'jedict';
	eval {
		$self->{dbh}->do("SET search_path TO $params{'Schema'}");
	};
	if($@){
		$self->{dbh}->disconnect;
		return undef;
	}
	return bless $self, $type;
}

sub close {
	my $self = shift;
	eval { $self->{dbh}->rollback };
	eval { $self->{dbh}->disconnect };
}

sub DESTROY {
	my $self = shift;
	jedict::close($self);
}
sub search {
	my ($self, $type, $string) = @_;
	my $result;

	if ($type == 1 or $type eq 'jap' or $type eq 'jpn') {
		$result = search_jap($self, $string);
	}
	if ($type == 2 or $type eq 'eng') {
		$result = search_eng($self, $string);
	}
	
	if(defined $result){
		return @{$result};
	} else {
		return ();
	}
}
sub search_jap {
	my ($self, $string) = @_;
	my @results;

	eval {
		my $sth;

		$sth = $self->{dbh}->prepare("SELECT * FROM jedict_main WHERE kanji LIKE ? OR kana LIKE ?");
		$sth->execute($string,$string);
		while(my $row = $sth->fetchrow_arrayref()){
		      push @results,
		        { 'kanji' => $row->[0],
		          'kana' => $row->[1],
			  'english' => $row->[2] };
		}
		$sth->finish();
	};
	if($@){
		#warn "jedict.pm: database error: $@\n";
		return undef;
	}
	# return results if any
	if($#results >= 0){
		return \@results;
	} else {
		return undef;
 	}
}

sub search_eng {
	my ($self, $string) = @_;
	my @results;	

	eval {
		my $sth;
		
		$sth = $self->{dbh}->prepare("SELECT * FROM jedict_main WHERE english LIKE ? OR english LIKE ? OR english LIKE ? or english LIKE ? OR english LIKE ? OR english LIKE ?");
		$sth->execute('% ' . $string . ' %',
				$string,
				 '%/' . $string . '/%',
				 '%/' . $string . ' %',
				 '%/' . $string . '%',
				 '% ' . $string . '/%');
		while (my $row = $sth->fetchrow_arrayref()) {
			push @results, { 'kanji' => $row->[0], 'kana' => $row->[1], 'english' => $row->[2] };
		}
		$sth->finish();
	};
	if($@){
		#warn "jedict.pm: database error: $@\n";
		return undef;
	}
	if ($#results >= 0) {
		return \@results;
	} else {
		return undef;
	}
}

sub update_database {
	my ($self, $file) = @_;
	$self->{counter} = 0;
	clear_pgdb($self) or die("FAIL: $!");
	eval {
		my $kanji;
		my $kana;
		my $english;
		open(EDICT, "<$file");;
		$self->{dbh}->do("COPY jedict_main FROM STDIN");
		while(<EDICT>) {
			if ($_ =~ m/(.*)\s\[(.*)\]\s/o) {
                		$kanji = $1;
				$kana = $2;
                		$_ =~ m/\s\/(.*)\/\n$/o;
                		$english = $1
        		} else {
                		if ($_ =~ m/(.*)\s\/(.*)\/\n$/o) {
					$kanji = "1337";
                	 	        $kana = $1;
					$english = $2;
                		}
			}
			$self->{dbh}->pg_putline(encode("utf8",decode("EUC_JP","$kanji\t$kana\t$english\n")));
			$self->{counter}++;
		}
		$self->{dbh}->pg_endcopy();
		$self->{dbh}->commit();
		close(EDICT);
	};
	if ($@) {
		#warn "jedict.pm: database error: $@\n";
		eval { $self->{dbh}->rollback() };
		return 0;
	}
	return $self->{counter};
}

sub clear_pgdb {	
	my $self = shift;
	eval {
		$self->{dbh}->do("DROP TABLE jedict_main");
		$self->{dbh}->do("CREATE TABLE jedict_main ( kanji varchar(512), kana varchar(512), english varchar(1024) )");
		$self->{dbh}->do("CREATE INDEX jedict_kana_index ON jedict_main (kana)");
	
		$self->{dbh}->commit();
	};
  	if($@){
    		#warn "jedict.pm: database error: $@\n";
    		eval { $self->{dbh}->rollback() };
		return 0;
  	}
	return 1;
}
1;
