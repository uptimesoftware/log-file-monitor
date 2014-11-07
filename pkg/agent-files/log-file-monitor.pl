#!/usr/bin/perl
use strict;
use warnings;

##############################################################################
# This log_monitor.pl script will search for occurrences of a string within 
# a list of files.  The script expects to be called with one large 
# concatenated variable that contains five other variables.  These variables
# represent the log file search criteria and are stored in %criteria.
# The criteria are compared against a bookmark file to ensure the same lines
# in the log files are not searched multiple times.  Once the files are have 
# been searched the bookmark file is updated with the last checked line and
# the occurrences are printed out.
##############################################################################

binmode STDOUT, ":utf8";
use utf8;
use MIME::Base64;  # for decoding command line argument
use Tie::File;  # for searching through log file and retain a line count
use Data::Dumper;  # for debugging the criteria and bookmark hashes

use Cwd            qw( abs_path );
use File::Basename qw( dirname );

##############################################################################
# get current working directory to determine if this is Windows or *nix
my $cwd = dirname(abs_path($0));
$cwd =~ s/\\/\//g;  # reorientate slashes for consistency
$cwd =~ s/\/$//g;  # strip off trailing slash

my $is_unix = 0;  # default Windows
$is_unix = 1 if ( $cwd =~ m/^\// );  # check if it's actually Unix


##############################################################################
# get the CLI variable and parse it into the main 5 variables
my $cmdlinevar = 0;
$cmdlinevar = $ARGV[1];
if ( !defined $cmdlinevar ) {
    # try the first argument instead
    $cmdlinevar = $ARGV[0];
}
# confirm that we received the necessary arguments by now
if ( !defined $cmdlinevar ) {
    print "Error: Arguments were not received by the agent script; quitting.\n";
    exit(1);
}

$cmdlinevar =~ s/(UPDOTTIME)/ /g;         # UPDOTTIME separates each variable
my @splitline = split(/ /, $cmdlinevar);  # split the command line variables

# criteria hash contains the search criteria provided by the service monitor
# 'directory':     directory to search in (string)
# 'files_regex':   regular expression of files to search within (string)
# 'search_regex':  regular expression of the string to find (string)
# 'ignore_regex':  lines will be ignored if they match this regex (string)
# 'debug_mode':    whether to produce debug output
# 'filename':      array of the files matching files_regex (array of strings)
# 'position':      array of bookmark positions (array of integers)
# 'bookmarkindex': corresponding bookmark array index (array of integers)
# the array indexes for 'filename', 'position', and 'bookmarkindex' match up
my %criteria;

# populate criteria hash with variables from the command line variable
$criteria{directory}    = decode_base64($splitline[0]);
$criteria{files_regex}  = decode_base64($splitline[1]);
$criteria{search_regex} = decode_base64($splitline[2]);
$criteria{ignore_regex} = decode_base64($splitline[3]);
$criteria{debug_mode}   = $splitline[4];

$criteria{directory} =~ s/\\/\//g;  # reorientate slashes for consistency
$criteria{directory} =~ s/\/$//g;  # strip off trailing slash

# set debug_mode variable properly (1 or 0)
if ( lc( $criteria{debug_mode} ) eq 'on' ) { $criteria{debug_mode} = 1; }
else { $criteria{debug_mode} = 0; }

# check if the directory exists before proceeding
if ( -d $criteria{directory} ) {
    # get list of files matching files_regex
    opendir(DIR, $criteria{directory}) || die "$!";
    #@{$criteria{filename}} = grep(/${criteria{files_regex}}/, readdir(DIR));
    push @{$criteria{filename}}, reverse map "$criteria{directory}/$_", 
      grep /^${criteria{files_regex}}$/, readdir( DIR );
    closedir(DIR);
}
else {
    print "Error: the directory, '$criteria{directory}', does not exist.\n";
    exit (1);
}

if ( $criteria{debug_mode} ) {
    #print "Hash of search items:\n";
    #print Dumper(\%criteria);
}


##############################################################################
# generated filename of the file which contains the bookmark positions
my $bookmarkfile = "${cwd}/elm-" . 
  replace_spec_chars( $criteria{directory} ) . ".bmf";


##############################################################################
# store the bookmark file into the bookmark array
# bookmark array structure ($bookmark[index]{key})
# 'filename':     absolute path to filename
# 'search_regex': regular expression search string 
# 'ignore_regex': regular expression ignore string 
# 'position':     last line searched
my @bookmark;
my $i;
if ( -s $bookmarkfile ) {  # if bookmark file is not empty
    open ( BOOKMARK, '<' . $bookmarkfile ) || 
      die ("Error: Could not open bookmark file, $bookmarkfile, for reading!");
    $i=0;
    while (my $line = <BOOKMARK>) {  # read bookmark file
        ($bookmark[$i]{filename}, $bookmark[$i]{search_regex}, 
          $bookmark[$i]{ignore_regex}, $bookmark[$i]{position}) = 
          ($line =~ 
          /filename:(.*);search_regex:(.*);ignore_regex:(.*?);position:(.*)/);
        $i++;
    }
    close ( BOOKMARK );

    if ( $criteria{debug_mode} ) {
        #print "Contents of bookmark file:\n";
        #print Dumper(@bookmark);
    }
}

# get number of bookmark entries
my $numbookmarks = scalar @bookmark;
$numbookmarks = 0 if ( $numbookmarks == -1 );


##############################################################################
# if in debug mode...
if ( $criteria{debug_mode} ) {
    print "Bookmark_File. $bookmarkfile\n";
    print "Checking_Dir. $criteria{directory}\n";
    print "File_Regex. $criteria{files_regex}\n";
    print "Search_String. $criteria{search_regex}\n";
    print "Ignore_String. $criteria{ignore_regex}\n";
    print "Checking_Files. ";
    print join ( ",  ", @{$criteria{filename}} );
    print "\n";
}


##############################################################################
# store previous bookmark array index in $criteria{position} array then search
my $j;
my @logfileArray;
my $logfile_eof;
my $linenum;
my $total_count = 0;  # count the number of occurrences
my $numfiles = scalar @{$criteria{filename}};
my $newnumbookmarks = $numbookmarks;
for $i ( 0 .. ($numfiles - 1) ) {
    # set criteria{position}[i] to zero to start
    # if doesn't change, then there was no bookmark entry
    $criteria{position}[$i] = 0;
    #print "Working on '$criteria{filename}[$i]'.\n";
    for $j ( 0 .. ( $numbookmarks - 1 ) ) {    
        #print "Does it match " . $bookmark[$j]{filename} . "?\n";
        if ( $criteria{filename}[$i] eq $bookmark[$j]{filename} and 
          $criteria{search_regex} eq $bookmark[$j]{search_regex} and 
          $criteria{ignore_regex} eq $bookmark[$j]{ignore_regex} ) {
            #print "yes!\n";
            $criteria{position}[$i] = $bookmark[$j]{position};
            $criteria{bookmarkindex}[$i] = $j;
            last;
        }
    }    

    
    ##################################################
    # start search 1000 lines earlier if in debug mode
    if ( $criteria{debug_mode} ) {
        $criteria{position}[$i] -= 1000;
        $criteria{position}[$i] = 0 if ($criteria{position}[$i] < 0);
    }


    ##################################################
    # read file into @logfileArray
    tie @logfileArray, 'Tie::File', "$criteria{filename}[$i]" || 
      print("Warning: Could not open file " . $criteria{filename}[$i] .
        ". Skipping file.\n");
    $logfile_eof = scalar @logfileArray;    # get the EOF position

    
    ##############################################################
    # check if the file rotated or the bookmark is no longer valid
    if ($criteria{position}[$i] > $logfile_eof) {
        # reset the bookmark to the beginning of the file
        $criteria{position}[$i] = 0;        
    }
    
    
    $linenum = $criteria{position}[$i];                
    #while ($line = <LOGFILE>) {
    while ( $linenum < $logfile_eof ){
        eval {
            ### try block
            # check if we need to ignore/skip the line
            if ( ( length( $criteria{ignore_regex} ) > 0 ) && 
              ( $logfileArray[$linenum] =~ m/${criteria{ignore_regex}}/i ) ) {
                # skip the line
            }
            else {
                eval {
                    ### try block
                    # check if the line matches the search regex
                    if ( $logfileArray[ $linenum ] =~
                      m/${criteria{search_regex}}/i ) {
                        $total_count++;
                        # print the first 50 matching lines to screen
                        # limit 50, so we don't overload up
                        if ($total_count <= 50) {
                            print $total_count . '. ' . 
                              $criteria{filename}[$i] . ", line " . 
                              (($linenum+1))." = '$logfileArray[$linenum]'\n";
                        }
                    }
                };
                if ($@) {
                    ### catch block
                    print ("Error: Invalid regular expression for search string.\n");
                    last;
                }
            }
        };
        if ($@) {
            ### catch block
            print ("Error: Invalid regular expression for ignore string.\n");
            last;
        }
        $linenum++;
    }

    # save new end of file position to bookmark array
    if ( defined $criteria{bookmarkindex}[$i] ) {        
        $bookmark[$criteria{bookmarkindex}[$i]]{position} = $logfile_eof;
    }
    else { # new bookmark entry
        $bookmark[$newnumbookmarks]{filename} = $criteria{filename}[$i];
        $bookmark[$newnumbookmarks]{position} = $logfile_eof;
        $bookmark[$newnumbookmarks]{search_regex} = $criteria{search_regex};
        $bookmark[$newnumbookmarks]{ignore_regex} = $criteria{ignore_regex};
        $newnumbookmarks++;
    }
    
    # untie the log file array
    untie @logfileArray;
}
    
    
##############################################################################
# write bookmark array back to bookmark file
open ( BOOKMARK, '>' . $bookmarkfile ) || 
  die ("Error: Could not open bookmark file, $bookmarkfile, for writing!");
my $line;
$i=0;
#print Dumper(@bookmark);
for $i ( 0 .. ( $newnumbookmarks - 1) ) {
    $line = "filename:$bookmark[$i]{filename};";
    $line = $line . "search_regex:$bookmark[$i]{search_regex};";
    $line = $line . "ignore_regex:$bookmark[$i]{ignore_regex};";
    $line = $line . "position:$bookmark[$i]{position}\n";
    print BOOKMARK $line;
    $i++;
}
close ( BOOKMARK );


##############################################################################
# print out the number of occurrences for the monitor
print("total_count $total_count\n");



##############################################################################
# convert slashes to periods and remove special characters
sub replace_spec_chars {
    my $str = shift;
    chomp($str);
    $str =~ s/\://g;    # get rid of ':'
    $str =~ s/\?//g;    # get rid of '?'
    $str =~ s/ //g;     # get rid of ' '
    $str =~ s/\|//g;    # get rid of '|'
    $str =~ s/\\/\./g;  # convert '\' to '.'
    $str =~ s/\//\./g;  # convert '/' to '.'    
    return $str;
}