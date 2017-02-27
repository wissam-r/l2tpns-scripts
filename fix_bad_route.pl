#!/usr/bin/perl -w
use strict;
use DBI;
use Time::Local;
use Sys::Load qw/getload/;
use Sys::RunAlone;
use Fcntl qw(LOCK_EX LOCK_NB);
use File::NFSLock;

if( scalar(@ARGV) < 4 ){
    print "ERROR input";
    exit();
}
my $server_ip = $ARGV[0];
my $host = $ARGV[1];
my $dbuser = $ARGV[2];
my $dbpass = $ARGV[3];
my $MAX_TRIALS = 5;
my $connected = 1;
my $retry = 0;
my $dbh;
my @rows;
my @DBips;
my @ServerIps;
my @mustD;

@ServerIps = getLNSIPs();
@DBips = getDBIPs();
@mustD = compareListIps(\@ServerIps,\@DBips);
delRoute(\@mustD);

sub compareListIps {

        my ($ipsA ,$ipsB) = @_;
    my @ipsIn = @{$ipsA};
        my @ipsNotIn = @{$ipsB};
        return grep { ! ( $_ ~~ @ipsNotIn ) } @ipsIn;
}
sub getLNSIPs {
	return `ip route | grep tun | awk '{print \$1}' | egrep -v '^10.*\/24\$'` ;
}
sub getDBIPs {
	$dbh = DBI->connect("dbi:Pg:dbname=fsdcm;host=$host;port=5432;user=$dbuser;password=$dbpass") or 0 ;
	
	if($dbh == 0) {
	        print "can't connect to DB";
	        exit() ;
	}
	
	my $get_time_now = "select now();";
	my $time_sth = $dbh->prepare($get_time_now);
	$time_sth->execute();
	my $time_now = $time_sth->fetchrow();
	$time_sth->finish();
	
	print "Time is NOW:".$time_now."\n";
	
	
	my $radid_query_all = "select username,framedipaddress from radacct where acctstoptime is null and nasipaddress::text like'%$server_ip%' and acctstarttime < '$time_now';";
	my $radid_sth = $dbh->prepare($radid_query_all);
	$radid_sth->execute();
	
	while(@rows = $radid_sth->fetchrow()) {
	               push (@DBips, "$rows[1]\n");
	             }
	$radid_sth->finish;
	$dbh->disconnect();
	return @DBips;
}
sub delRoute {
    my ($ipsR) = @_;
    my @ips = @{$ipsR};
    foreach my $ip (@ips){
        chomp ($ip) ;
     	`/sbin/ip route del $ip`;
     	#print $ip;
    }
}
__END__
