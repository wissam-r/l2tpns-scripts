#!/usr/bin/perl -w

use strict;
use warnings;
use Net::Telnet;
use Text::TabularDisplay;
use Sys::RunAlone;

my $UserName ;
my $Port ;
my $id =0;
if( scalar(@ARGV) == 2 ) {
        $UserName           = $ARGV[0];
		$Port				= $ARGV[1];
}else{
        print "ERROR";
        exit();
}

my %EXIT		= (OK => 0, WARNING => 1, CRITICAL => 2);
my $hostname	= `/bin/hostname -s`;
chop($hostname);
my @servers		= (
					{Host => '127.0.0.1', Port => $Port}
				);
my $status		= $EXIT{OK};
my @users;
my @failures;
my @tunnels;
my %hash;
my $re='.*?(\\d+)(\\s+)(\\d+)(\\s+).*?(@)(sawaisp\\.sy)(\\s+)((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)((?:[a-z][a-z0-9_]*))(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)(\\d+)(\\s+)((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))(?![\\d])(\\s+)(.)';
foreach my $server (@servers) {
	my @table		= ();
	my $t = new Net::Telnet (Host => ${$server}{Host},Port => ${$server}{Port}, Timeout => 60, Prompt => "/$hostname> \$/", Errmode => 'return');
	if (!defined($t)) {
		push @failures, $server;
		$status = $EXIT{WARNING};
	} else {
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

		# Parse sessions data
		foreach my $row (@users) {
			 if ($row =~ m/$re/is){
				($id) = ($1);
				if(index($row,$UserName ) != -1) {
					my $before = substr $row, index ( $row,$UserName )-1 , 1;
					if ($before =~ /^ *$/) {
						print $id ;
					}

                		} 
			}
		}
	}
}
__END__
