#!/usr/bin/perl

use strict;
use warnings;
use Net::Telnet;
use Text::TabularDisplay;
use Sys::RunAlone;

my %EXIT		= (OK => 0, WARNING => 1, CRITICAL => 2);
my $hostname	= `/bin/hostname -s`;
chop($hostname);

my @servers		= (
				{Host => '127.0.0.1', Port => '1025'},
				{Host => '127.0.0.1', Port => '1026'},
				{Host => '127.0.0.1', Port => '1027'},
				{Host => '127.0.0.1', Port => '1028'},
				{Host => '127.0.0.1', Port => '1029'},
				{Host => '127.0.0.1', Port => '1030'},
				{Host => '127.0.0.1', Port => '1031'},
				{Host => '127.0.0.1', Port => '1032'},
				{Host => '127.0.0.1', Port => '1033'},
				);
my $status		= $EXIT{OK};
my @users;
my @failures;
my @tunnels;
my %hash;
my $re='.*?(\\d+)(\\s+)(\\d+)(\\s+).*?(@)(sawaisp\\.sy)(\\s+)((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])(\\s+)(.)';
foreach my $server (@servers) {
	my @table		= ();
	my $t = new Net::Telnet (Host => ${$server}{Host},Port => ${$server}{Port}, Timeout => 30, Prompt => "/$hostname> \$/", Errmode => 'return');
	if (!defined($t)) {
		push @failures, $server;
		$status = $EXIT{WARNING};
	} else {
		my $wrapper 	= Text::TabularDisplay->new;
		# Resize buffer for large data
		$t->max_buffer_length(10 * 1024 * 1024);
		# Get data
		@users = $t->cmd('show session');
		$t->waitfor("$hostname");
		@tunnels = $t->cmd('show tunnels');
		$t->waitfor("$hostname");
		$t->close();

		# Check data existance
		if (scalar(@users) < 10) {
			exit 3;
		}
		print "\nServer\t:\t" . ${$server}{Host} .":" . ${$server}{Port} . "\n";
		print "Users\t:\t" . (scalar(@users) - 3) . "\nTunnels\t:\t" . (scalar(@tunnels) - 2) . "\n\n";

		# Parse tunnels data
		foreach my $row (@tunnels) {
			if ($row =~ /(\d+)\s+([\w:\-_]+)\s+(\d+\.\d+\.\d+\.\d+)\s+\w+\s+(\d+)/) {
	
				my ($id,$name,$ip,$sessions) = ($1,$2,$3,$4);
				$hash{$3} = scalar(@table);
				push @table, {ID => $id, Name => $name, IP => $ip, TotalSessions => $sessions, RealSessions => 0, BadSessions => 0, Sessions => []};
			}
		}

		# Parse sessions data
		foreach my $row (@users) {
			if ($row =~ /(\d+)\s+\d+\s+\d+\s+([\w\.\-_\*]+)(?:\@sawaisp\.sy)?\s+\d+\.\d+\.\d+\.\d+\s+[NY]\s+[NY]\s+[NY]\s+[NY]\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\(L\)(\d+\.\d+\.\d+\.\d+)\s+/) {
			
				my ($id,$username,$lac) = ($1,$2,$3);
				push @{$table[$hash{$lac}]{Sessions}}, {ID => $id, Username => $username};
				if ($username eq "*") {
					$table[$hash{$lac}]{BadSessions} += 1;
				} else {
					$table[$hash{$lac}]{RealSessions} += 1;
				}
			}
			if ($row =~ m/$re/is){
				my ($id,$username,$lac) = ($2,$6,$28);
				push @{$table[$hash{$lac}]{Sessions}}, {ID => $id, Username => $username};
            ;
				if(index($row, "0.0.0.0") != -1) {
                    $table[$hash{$lac}]{BadSessions} += 1;
                } else {
                    $table[$hash{$lac}]{RealSessions} += 1;
                }	
			}
		}

		$wrapper->columns("ID","Name","IP","Total Sessions","Real Sessions","Bad Sessions");
		my $tsessions = 0 ;
		my $rsessions = 0 ;
		my $bsessions = 0 ;
		foreach my $row (@table) {
			$tsessions += ${$row}{TotalSessions} ;
			$rsessions += ${$row}{RealSessions} ;
			$bsessions += ${$row}{BadSessions} ;
		if (  ( ${$row}{TotalSessions} - ${$row}{RealSessions} ) < 0 ) {
			$wrapper->add(${$row}{ID},${$row}{Name},${$row}{IP},${$row}{TotalSessions},${$row}{RealSessions}, 0 )
		}
		else {
		$wrapper->add(${$row}{ID},${$row}{Name},${$row}{IP},${$row}{TotalSessions},${$row}{RealSessions},${$row}{TotalSessions} - ${$row}{RealSessions})	;
		}
		}
		if ( ( $tsessions - $rsessions ) < 0 ){
		$wrapper->add("","Total","",$tsessions,$rsessions,0);}
		else{
		$wrapper->add("","Total","",$tsessions,$rsessions,$tsessions - $rsessions);
}
		print $wrapper->render . "\n\n";
	}
}
exit $status;
__END__
