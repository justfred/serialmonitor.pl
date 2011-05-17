#!perl -w
my $ProgName = "smdr_load.pl";
#ftp cs data
#
#History
my $ProgVersion = "020725";
#020725 FH
#	Checked; corrected.
#020408 FH
#	First Version
#
#Externals
use strict; 
use DBI; 
use lib("z:/billing/perl/toolbox");
use toolbox;
use cy_db;
#use smdr; #smdr_import

#Constants
my $TRUE=1;
my $FALSE=0;

########################################
# Local subroutines

#counter
my $timer_start;

#local variables
#my $start=1;

my $filename;
my $fileline;

########################################
# csc - CS CDR

my $SMDR_DSN="intra";
my $SMDR_TABLE="smdr";
my %tbl_smdr;

sub smdr_prep() {

	%tbl_smdr=(DSN=>$SMDR_DSN,TABLENAME=>$SMDR_TABLE);
	cydb_init_table(\%tbl_smdr);
	$tbl_smdr{template} = cydb_template(\%tbl_smdr);

}

sub smdr_insert($$$$) {
my ($ref_smdr_table,$filename,$fileline,$dat)=@_;
# insert qualiifying data into smdr table.
	my @rec;

	my $type; #sorry, you're not my type.

	my $cdr_type=substr($dat,0,1);
	my $return=0; #return value

	if ((pTrim($dat) eq "") or
		(substr($dat,2,2) eq "**") or
		(substr($dat,1,3) eq "STA")) {
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
		${$ref_smdr_table}{sth_ins}->execute($filename,$fileline,@rec);

		$return=1;
	}
return $return;
} #smdr_insert

sub smdr_version() {
	print "$ProgName\n";
	print "Version $ProgVersion\n\n";
}

########################################
#main

my @dir_files;

print "$ProgName\n";
print "Version $ProgVersion\n\n";

smdr_prep;

#I should have a method to just process all files in the directory.
print "chdir z:\\billing\\smdr\\dat\\\n";
chdir "z:\\billing\\smdr\\dat" or die "ERROR: could not change directory.\n";
opendir(DIR_HANDLE,"z:\\billing\\smdr\\dat");
@dir_files=readdir(DIR_HANDLE);
foreach (@dir_files) {
print "File $_\n";
		if (m/dat$/) {
print "Processing $_\n";
#			smdr_import($_)	
			$filename=$_;
			cydb_file_import(\%tbl_smdr,\&smdr_insert,$filename);
		}
}

print "$ProgName complete.\n";