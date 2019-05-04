#! /usr/bin/env perl
###############################################################################
# N1 - GTKWave Save File and STEMS File Generator                             #
###############################################################################
#    Copyright 2018 - 2019 Dirk Heisswolf                                     #
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
#    This script generates a STEMS file for source code browsing and signal   #
#    annotation in GTKWave.                                                   #
#                                                                             #
###############################################################################
# Version History:                                                            #
#   May 3, 2019                                                               #
#      - Initial release                                                      #
###############################################################################

#################
# Perl settings #
#################
use 5.005;
use FindBin qw($RealBin);
use lib "$RealBin/blib/arch";
use lib "$RealBin/blib/lib";
use lib "$RealBin";

use Getopt::Long;
use IO::File;

use Verilog::Netlist;
use Verilog::Netlist::Module;
use Verilog::Getopt;
use strict;

############################
# Parse Verilog parameters #
############################
my $vopt = new Verilog::Getopt(filename_expansion=>1);
@ARGV = $vopt->parameter(@ARGV);

###########
# Netlist #
###########
my $nl = new Verilog::Netlist (options => $vopt,
			       keep_comments => 1,
			       use_vars => 1);

##############
# Top module #
##############
my $top_mod_ref;

###########
# Filters #
###########
my %filters         = ();
my $filter_cnt      = 0;
my $filter_basename = "./filter";
    
##############################
# Parse remaining parameters #
##############################
my $trace_name;
my $gtkw_name;
my $stems_name;
my @file_names = ();
my $top_mod_name;
my $ropt = Getopt::Long::Parser->new;
$ropt->configure("no_pass_through");
if (! $ropt->getoptions ("help"	        => \&help,
			 "trace=s"	=> \$trace_name,
			 "stems=s"	=> \$stems_name,
			 "top=s"        => \$top_mod_name,
			 "<>"		=> \&files)) {
    die sprintf("Try %s -help\n", $0);
}  

#Set filter basename
if ($trace_name) {
    $filter_basename = $trace_name;
    $filter_basename =~ s/\.vcd$/_filter/;
    $filter_basename =~ s/\.fst$/_filter/;
} elsif ($stems_name) {
    $filter_basename = $stems_name;
    $filter_basename =~ s/\.stems$/_filter/;
}

parse_verilog();
generate_stems_file();
    
exit (0);

#############
# Help text #
#############
sub help {
    printf("usage: %s -top <module> -trace <trace file> -stems <stems file> [verilog parser options]\n", $0);
    printf("       Supported verilog parser options:\n");    
    printf("            +libext+I<ext>+I<ext>...    libext (I<ext>)\n");
    printf("            +incdir+I<dir>              incdir (I<dir>)\n");
    printf("            +define+I<var>=I<value>     define (I<var>,I<value>)\n");
    printf("            +define+I<var>              define (I<var>,undef)\n");
    printf("            -F I<file>                  Parse parameters in file relatively\n");
    printf("            -f I<file>                  Parse parameters in file\n");
    printf("            -v I<file>                  library (I<file>)\n");
    printf("            -y I<dir>                   module_dir (I<dir>)\n");
    printf("            -DI<var>=I<value>           define (I<var>,I<value>)\n");
    printf("            -DI<var>                    define (I<var>,undef)\n");
    printf("            -UI<var>                    undefine (I<var>)\n");
    printf("            -II<dir>                    incdir (I<dir>)\n");
exit (1);
}

###############
# Input files #
###############
sub files {
    my $file = shift;
    push @file_names, "$file";
}

#################
# Parse verilog #
#################
sub parse_verilog {
    #Create new netlist
    #Read libraries
    $nl->read_libraries();

    #Read files
    foreach my $file_name (@file_names) {
	$nl->read_file (filename=>$file_name);
    }
    
    #Find top module
    if ($top_mod_name) {
	#Check given top module
	$top_mod_ref = $nl->find_module($top_mod_name) or die "Can't find $top_mod_name\n";
	$top_mod_ref->is_top(1);
    } else {
	#Find top module 
	foreach $top_mod_ref ($nl->modules) {
	    if ($top_mod_ref->is_top) {
		$top_mod_name = $top_mod_ref->name;
		last;
	    }
	} 
    }
    
    #Resolve references    
    $nl->link();
    $nl->lint();
    $nl->exit_if_error();
}

#######################
# Generate STEMS file #
#######################
sub generate_stems_file {
    
    #Only act if STEMS file is requested
    if ($stems_name) {
	my $out_handle = IO::File->new;
	$out_handle->open(">$stems_name") or die "Can't open $stems_name\n";

	#Parse hierarchy tree
	parse_stems($out_handle, $top_mod_ref);

	#close file
	$out_handle->close;
    }	
}

sub parse_stems {
    my $out_handle     = shift;
    my $parent_mod_ref = shift;

    #Obtain module information
    my $name       = $parent_mod_ref->name;
    my $file_name  = $parent_mod_ref->filename;
    my $first_line = $parent_mod_ref->lineno;
    #Determine last line of source code
    my $in_handle = IO::File->new;
    $in_handle->open("<$file_name") or die "Can't open $file_name\n";
    my $last_line = 0;
    while (my $line = <$in_handle>) {
	$last_line++;
    }
    $in_handle->close();
    
    #Write module definition to STMS file
    $out_handle->printf("++ module %s file %s lines %d - %d\n", $name,
			                                        $file_name,
		       	                                        $first_line,
			                                        $last_line);
    #printf("++ module %s file %s lines %d - %d\n", $name,
    #	                                           $file_name,
    #	                                           $first_line,
    #	                                           $last_line);

    #Write signal definitions
    foreach my $net_ref ($parent_mod_ref->nets_sorted()) {
	if ($net_ref->decl_type ne "parameter") {
	    $out_handle->printf("++ var %s module %s\n", $net_ref->name,
	  			                         $name);
	    #printf("%s[%d:%d]\n", $net_ref->name, num($net_ref->msb), num($net_ref->lsb));
	}
   }

    #Write child relations
    my @cell_refs = $parent_mod_ref->cells_sorted();
    foreach my $cell_ref (@cell_refs) {
	my $inst_name = $cell_ref->name;
	my $mod_name  = $cell_ref->submodname;
	$out_handle->printf("++ comp %s type %s parent %s\n", $inst_name,
			                                      $mod_name,
			                                      $name);
    }
 
    #Parse children
    foreach my $cell_ref (@cell_refs) {
	my $mod_ref  = $cell_ref->submod;
	parse_stems($out_handle, $mod_ref);
    }
}


1;
