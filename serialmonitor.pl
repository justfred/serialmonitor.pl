#! perl -w
my $ProgName="serialmonitor.pl";
#
#DESCRIPTION
#monitor the specified serial port
#log anything that comes in to a file.
#AND insert it into the database.
#
#HISTORY
my $ProgVersion="020819";
#041227 FH
#	Comments
#	Review code
#020819 FH
#	Minor cleanup
#020807 FH
#	First version.
#
#Externals
use strict;
#this is needed for Win32; how do we do it in Linux?
use Win32::SerialPort;
#use DBI; #DBI is defined in cy_db.
use lib("z:/billing/toolbox");
use toolbox; #my personal functions
use cy_db; #cybertel database functions; this contains the constants for our DB

my $ob; #serial port object

my $baud = 9600;
my $parity = "none";
my $data = 8;
my $stop = 1;
my $hshake = "none";

my $datetime;
my @now;
my $filename;
my $fileline=1;

########################################
# csc - CS CDR

my $SMDR_DSN="intra";
my $SMDR_TABLE="smdr";
my %tbl_smdr;

sub smdr_prep() {
#initialize the smdr table

	%tbl_smdr=(DSN=>$SMDR_DSN,TABLENAME=>$SMDR_TABLE);
	cydb_init_table(\%tbl_smdr);
	$tbl_smdr{template} = cydb_template(\%tbl_smdr);

#print "template : $tbl_smdr{template}\n";
}

#####

sub smdr_insert($$$$) {
my ($ref_smdr_table,$filename,$fileline,$dat)=@_;
# insert qualiifying data into smdr table.
#
#NOTES
#	this could either be SMDR-specific (named fields for each SMDR field), or generic (a single field for the SDMR string, plus line number, file name, etc.).

	my @rec;

	my $type; #sorry, you're not my type.

#	my $cdr_type=substr($dat,0,1);
	my $return=0; #return value

#this is specific to the Vodavi Starplus SMDR
#skip gearders, that start with STA
#still trying to find 'STA'
#print "substr(dat,10,3) : ".substr($dat,10,3)."\n";
	if ((pTrim($dat) eq "") or
		(substr($dat,2,2) eq "**") or
		(substr($dat,3,3) eq "STA") or
		(length($dat) < 33)) {
#print "(**/STA record skipped.)\n";
		$return=0;
	} else {
#print "dat : $dat\n";

		@rec=unpack(${$ref_smdr_table}{template}, $dat);

		#Trim spaces from all.
		foreach (@rec) {
			$_=pTrim($_);
		}
		#rec 0 is station - trim leading zero
		$rec[0]=substr($rec[0],1,3);
#print "extn: $rec[0]\n";
		#rec 6 is dialed - trim leading 1, add 760 to 7-digiters, limit to 10 digits
		$rec[6]=trim(substr($rec[6],1)) if ((length($rec[6]) > 7) and (substr($rec[6],0,1) eq '1'));
		$rec[6]="760".$rec[6] if (length($rec[6]) == 7);
		$rec[6]=substr($rec[6],0,10) if (length($rec[6]) > 10);
#print "dialed: $rec[6]\n";

		#this should filter out garbage
		unless (pNull($rec[0])) {
			${$ref_smdr_table}{sth_ins}->execute($filename,$fileline,@rec);
		} else {
			print "(null record skipped.)\n";
		}

		$return=1;
	}
return $return;
} #smdr_insert


#####

sub open_serial() {
#this is the Windows serial port open

print "opening COM1 : ";
	$ob = Win32::SerialPort->new ('COM1') || die;
}

#####

sub set_serial() {
#this sets the serial port settings
#Windows-specific

	$ob->baudrate($baud) 	|| die "fail setting baud";
	$ob->parity($parity) 	|| die "fail setting parity";
	$ob->databits($data) 	|| die "fail setting databits";
	$ob->stopbits($stop) 	|| die "fail setting stopbits";
	$ob->handshake($hshake)	|| die "fail setting handshake";

	$ob->write_settings 	|| die "no settings"; 
}

#####

sub get_serial() {
#this checks the serial port settings
#Windows-specific

	my $baud = $ob->baudrate;
	my $parity = $ob->parity;
	my $data = $ob->databits;
	my $stop = $ob->stopbits;
	my $hshake = $ob->handshake;

	print "$baud $data/$parity/$stop\n";
}

#####

sub read_serial() {
#print "\@read_serial...\n";
#read serial port until interrupted

	my $stopnow=0;

	while (!$stopnow) {
		$ob->read_interval(100); #read interval in miliseconds
# this should wait 1000 miliseconds, instead it seems to wait till it gets data.
		my ($count, $result) = $ob->read(80); #characters to read
#I'm reading an 80-character line
		if ($result) {
#print "$filename($fileline) :\n";
			print "$result";
			#insert result into call_detail
			smdr_insert(\%tbl_smdr,$filename,$fileline,$result);
			#could also write the data to flat file now.
			#I open append, then close here so the file is always written, not cached.
			open SMDR_FILE, ">>dat/$filename.txt";
			print SMDR_FILE $result;
			close SMDR_FILE;
			$fileline++;
		}
	}
}

#####

sub close_serial() {
	undef $ob; 
}

#####
#MAIN

print "$ProgName\n";
print "Version $ProgVersion\n\n";

	smdr_prep();

	@now=localtime;
	$datetime=sprintf("%04d",$now[5]+1900)
		.sprintf("%02d",$now[4]+1)
		.sprintf("%02d",$now[3])
		.sprintf("%02d",$now[2])
		.sprintf("%02d",$now[1]);
	$filename="serialmonitor_".$datetime;

	print "filename : $filename\n";

	print "appending to SMDR_FILE dat/$filename.txt\n";

	open_serial();
	set_serial();
	get_serial();
	read_serial();
	close_serial();

