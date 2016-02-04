#! /usr/bin/perl

use strict;
use warnings;
use Getopt::Tabular;
use NeuroDB::DBI;
use File::Basename;

my $profile =   undef;
my @args;

my $Usage   =   <<USAGE;

This script goes through a list of files in the mri_protocol_violated_scans table, copy the mincfile 
into a new directory called violatedscans/ within the data_dir

Usage: perl database_files_update.pl [options]

-help for options

USAGE

my @args_table  =   (["-profile",   "string",   1,  \$profile,  "name of config file in ../dicom-archive/.loris_mri."]
                    );

Getopt::Tabular::SetHelp ($Usage, '');
GetOptions(\@args_table, \@ARGV, \@args)    ||  exit 1;

# Input option error checking
{ package Settings; do "$ENV{LORIS_CONFIG}/.loris_mri/$profile" }
if  ($profile && !@Settings::db)    { 
        print "\n\tERROR: You don't have a configuration file named '$profile' in:  $ENV{LORIS_CONFIG}/.loris_mri/ \n\n"; 
            exit 33; 
}
if  (!$profile) { 
        print "$Usage\n\tERROR: You must specify a profile.\n\n";  
            exit 33;
}

# These settings are in the config file (profile)
my  $data_dir   =   $Settings::data_dir;
my $violated_dir_name = "violatedscans";

# Establish database connection
my $dbh     =   &NeuroDB::DBI::connect_to_db(@Settings::db);
print LOG "\n==> Successfully connected to database \n";


#### Updating minc location in files table ####
my  ($minc_location_refs, $fileIDs_minc) =   get_minc_files($data_dir, $dbh);    # list all mincs in mri_protocol_violated_scan table
if  ($minc_location_refs) {
    foreach my $fileID (@$fileIDs_minc) {
        my($initial_path)      =  $minc_location_refs->{$fileID};
        my($minc_filename, $dir, $ext)      =  fileparse($initial_path);
        my (@basedir_arr) = split (/\//, $dir);
	print "Basedir is $basedir_arr[$#basedir_arr] \n";
        my $duplicate_minc      =  $data_dir . "/trashbin/$basedir_arr[$#basedir_arr]/" . $minc_filename;
	print "Duplicate minc full path is $duplicate_minc \n";
#        my $new_minc_location      =  $data_dir . "/" . $violated_dir_name . "/" . $minc_filename;
        my $new_minc_location      =  $duplicate_minc;

=pod
        if (-e $duplicate_minc) {
       	    my $copy = "cp $duplicate_minc $new_minc_location";
	    print "Copying now $minc_filename from $initial_path to $new_minc_location \n";
	    `$copy`;
        }

=cut
        if (-e $duplicate_minc) {

            my  ($rows_affected)    =   update_minc_location($fileID, $new_minc_location, $dbh); # update minc location in files table.
            if  ($rows_affected ==  1)  { 
                print "Updated location of minc with $fileID FileID to $new_minc_location.\n";
            } else {
            print "ERROR: $rows_affected while updating minc with $fileID FileID to $new_minc_location.\n";
            }
        }
    }

} else {
    print LOG "No file was found with a path starting from the root directory (i.e. including $data_dir)\n";
}



###############
## Functions ##
###############

=pod
Get list of minc files to update location in the files table.
=cut
sub get_minc_files {
    my ($data_dir, $dbh)   =   @_;

    my (%minc_locations,@fileIDs);
    my $query  =   "SELECT ID, minc_location "  .
                    "FROM mri_protocol_violated_scans";
    my $sth    =  $dbh->prepare($query);
    $sth->execute();

    if  ($sth->rows > 0) {
        while (my $row  = $sth->fetchrow_hashref()) { 
            my  $fileID =   $row->{'ID'};
            push    (@fileIDs, $fileID); 
            $minc_locations{$fileID}    =   $row->{'minc_location'};
        }
    } else {
        return  undef;
    }

    return  (\%minc_locations, \@fileIDs);
}

=pod
Update location of minc files in the files table.
=cut
sub update_minc_location {
    my  ($fileID, $new_minc_location, $dbh) =   @_;                # update minc location in files table.

    my  $query          =   "UPDATE mri_protocol_violated_scans " .
                            "SET minc_location=? " .
                            "WHERE ID=?";
    my  $sth            =   $dbh->prepare($query);
    my  $rows_affected  =   $sth->execute($new_minc_location,$fileID);

    return  ($rows_affected);
}

