#! /usr/bin/env perl
##############################################################################
#                               N1 ASSEMBLER                                  #
###############################################################################
#    Copyright 2024 Dirk Heisswolf                                            #
#    This file is part of the N1 project.                                     #
#                                                                             #
#    N1 is free software: you can redistribute it and/or modify               #
#    it under the terms of the GNU General Public License as published by     #
#    the Free Software Foundation, either version 3 of the License, or        #
#    (at your option) any later version.                                      #
#                                                                             #
#    N1 is distributed in the hope that it will be useful,                    #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
#    GNU General Public License for more details.                             #
#                                                                             #
#    You should have received a copy of the GNU General Public License        #
#    along with N1.  If not, see <http://www.gnu.org/licenses/>.              #
###############################################################################
# Description:                                                                #
#   N1 command line assembler, based on the HSW12 assembler                   #
#   (https://github.com/hotwolf/HSW12).                                       #
###############################################################################
=pod
=head1 NAME

N1asm.pl - N1 Command Line Assembler

=head1 SYNOPSIS

 N1asm.pl <src files> -L <library pathes> -D <defines: name=value or name>

=head1 REQUIRES

perl5.005, N1asm, File::Basename, FindBin, Data::Dumper

=head1 DESCRIPTION

This script is a command line frontend to the N1 Assembler.

=head1 METHODS

=over 4

=item N1.pl <src files> -L <library pathes> -D <defines: name=value or name>

 Starts the N1 Assembler. 
 This script reads the following arguments:
     1. src files:      source code files(*.s)
     2. library pathes: directories to search for include files
     3. defines:        assembler defines

=back

=head1 AUTHOR

Dirk Heisswolf

=head1 VERSION HISTORY

=item V00.00 - Feb 9, 2003

 initial release

=item V00.01 - Apr 2, 2003

 -added "-s28" and "-s19" command line options

=item V00.02 - Apr 29, 2003

 -making use of the new "verbose mode"

=item V00.03 - Sep 21, 2009

 -made script more platipus friendly

=item V00.04 - Jun 8, 2010

 -truncate all output files

=item V00.05 - Jan 19, 2010

 -support for incremental compiles

=item V00.06 - Feb 14, 2013

 -S-Record files will be generated in the source directory

=cut

#################
# Perl settings #
#################
use 5.005;
#use warnings;
use File::Basename;
use FindBin qw($RealBin);
use Data::Dumper;
use lib $RealBin;
require N1asm;

###############
# global vars #
###############
@src_files         = ();
@lib_files         = ();
%defines           = ();
$output_path       = ();
$prog_name         = "";
$arg_type          = "src";
$symbols           = {};
$code              = {};

##########################
# read command line args #
##########################
#printf "parsing args: count: %s\n", $#ARGV + 1;
foreach $arg (@ARGV) {
    #printf "  arg: %s\n", $arg;
    if ($arg =~ /^\s*\-L\s*$/i) {
	$arg_type = "lib";
    } elsif ($arg =~ /^\s*\-D\s*$/i) {
	$arg_type = "def";
    } elsif ($arg =~ /^\s*\-/) {
	#ignore
    } elsif ($arg_type eq "src") {
	#sourcs file
	push @src_files, $arg;
    } elsif ($arg_type eq "lib") {
	#library path
	if ($arg !~ /\/$/) {$arg = sprintf("%s%s", $arg, $N1asm::path_del);}
	unshift @lib_files, $arg;
        $arg_type          = "src";
    } elsif ($arg_type eq "def") {
	#precompiler define
	if ($arg =~ /^\s*(\w+)=(\w+)\s*$/) {
	    $defines{uc($1)} = $2;
	} elsif ($arg =~ /^\s*(\w+)\s*$/) {
	    $defines{uc($1)} = "";
	}
        $arg_type          = "src";
    }
}

###################
# print help text #
###################
if ($#src_files < 0) {
    printf "usage: %s [-s19|-s28] [-L <library path>] [-D <define: name=value or name>] <src files> \n", $0;
    print  "\n";
    exit;
}

#######################################
# determine program name and location #
#######################################
$prog_name   = basename($src_files[0], ".s");
$output_path = dirname($src_files[0], ".s");

###################
# add default lib #
###################
#printf "libraries:    %s (%s)\n",join(", ", @lib_files), $#lib_files;
#printf "source files: %s (%s)\n",join(", ", @src_files), $#src_files;
if ($#lib_files < 0) {
  foreach $src_file (@src_files) {
    #printf "add library:%s/\n", dirname($src_file);
    push @lib_files, sprintf("%s%s", dirname($src_file), $N1asm::path_del);
  }
}

####################
# load symbol file #
####################
$symbol_file_name = sprintf("%s%s%s.sym", $output_path, $N1asm::path_del, $prog_name);
#printf STDERR "Loading: %s\n",  $symbol_file_name;
if (open (FILEHANDLE, sprintf("<%s", $symbol_file_name))) {
    $data = join "", <FILEHANDLE>;
    eval $data;
    close FILEHANDLE;
}
#printf STDERR $data;
#printf STDERR "Importing %s\n",  join(",\n", keys %{$symbols});
#exit;

#######################
# compile source code #
#######################
#printf STDERR "src files: \"%s\"\n", join("\", \"", @src_files);  
#printf STDERR "lib files: \"%s\"\n", join("\", \"", @lib_files);  
#printf STDERR "defines:   \"%s\"\n", join("\", \"", @defines);  
$code = N1asm->new(\@src_files, \@lib_files, \%defines, "S12", 1, $symbols);

###################
# write list file #
###################
$list_file_name = sprintf("%s%s%s.lst", $output_path, $N1asm::path_del, $prog_name);
if (open (FILEHANDLE, sprintf("+>%s", $list_file_name))) {
    $out_string = $code->print_listing();
    print FILEHANDLE $out_string;
    #print STDOUT     $out_string;
    #printf "output: %s\n", $list_file_name;
    close FILEHANDLE;
} else {
    printf STDERR "Can't open list file \"%s\"\n", $list_file_name;
    exit;
}

#####################
# check code status #
#####################
if ($code->{problems}) {
    printf STDERR "Problem summary: %s\n", $code->{problems};
    $out_string = $code->print_error_summary();
    print STDERR $out_string;
} else {
    ###################################
    # give memory allocation overview #
    ###################################
    $out_string = $code->print_mem_alloc();
    print STDERR     "\n" . $out_string;
    
    #####################
    # write symbol file #
    #####################
    if (open (FILEHANDLE, sprintf("+>%s", $symbol_file_name))) {
	$dump = Data::Dumper->new([$code->{comp_symbols}], ['symbols']);
	$dump->Indent(2);
	print FILEHANDLE $dump->Dump;
 	close FILEHANDLE;
    } else {
	printf STDERR "Can't open symbol file \"%s\"\n", $symbol_file_name;
	exit;
    }

    ###############################
    # write Verilog readmemh file #
    ###############################
    $mem_file_name = sprintf("%s%s%s.mem", $output_path, $N1asm::path_del, $prog_name);
    if (open (FILEHANDLE, sprintf("+>%s", $mem_file_name))) {
	$out_string = $code->print_mem_file();
	print FILEHANDLE $out_string;
	close FILEHANDLE;
    } else {
	printf STDERR "Can't open memory load file \"%s\"\n", $mem_file_name;
	exit;
    }

}















