#!/usr/bin/perl
#serial port monitor, UNIX
#
#NOTES
#	uses IO::Handle
#	uses IPC::Open2 (or Open3) to open processes

sub strftime ($@) {
	my ($format,$second,$minute,$hour,$day,$month,$year) = @_;
	my %convert = (
		Y => $year + 1900,
		m => sprintf( '%02d',$month + 1 ),
		d => sprintf( '%02d',$day ),
		H => sprintf( '%02d',$hour ),
		M => sprintf( '%02d',$minute ),
		S => sprintf( '%02d',$second ),
		);
	$format =~ s#%(.)#$convert{$1}#sg;
	$format;
}

use IO::Handle;
use IPC::Open2;
$rootlog = "/var/log/smdrlog";
$modem_device = "/dev/ttya30";
my $stty = '/bin/stty -g';
open2( MODEM_IN, MODEM_OUT, "cu -l $modem_device -s1200 2>&1");
system("/usr/bin/stty $stty");
while () {
	$_ = ;
	$logfile = strftime("%m%d%Y",localtime());
	open(LOGFILE,">>$rootlog/$logfile");
	print LOGFILE $_;
	close LOGFILE;
}
