#! /usr/bin/env perl
###############################################################################
# WbXbc - GTKWave Save File and STEMS File Generator                          #
###############################################################################
#    Copyright 2018 Dirk Heisswolf                                            #
#    This file is part of the WbXbc project.                                  #
#                                                                             #
#    WbXbc is free software: you can redistribute it and/or modify            #
#    it under the terms of the GNU General Public License as published by     #
#    the Free Software Foundation, either version 3 of the License, or        #
#    (at your option) any later version.                                      #
#                                                                             #
#    WbXbc is distributed in the hope that it will be useful,                 #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of           #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
#    GNU General Public License for more details.                             ##                                                                             #
#    You should have received a copy of the GNU General Public License        #
#    along with WbXbc.  If not, see <http://www.gnu.org/licenses/>.           #
###############################################################################
# Description:                                                                #
#    This script generates an initial GTKW file to speed up debugging.        #
#                                                                             #
###############################################################################
# Version History:                                                            #
#   October 23, 2018                                                          #
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
			 "gtkw=s"	=> \$gtkw_name,
			 "top=s"        => \$top_mod_name,
			 "<>"		=> \&files)) {
    die sprintf("Try %s -help\n", $0);
}  

#Set filter basename
if ($trace_name) {
    $filter_basename = $trace_name;
    $filter_basename =~ s/\.vcd$/_filter/;
    $filter_basename =~ s/\.fst$/_filter/;
} elsif ($gtkw_name) {
    $filter_basename = $gtkw_name;
    $filter_basename =~ s/\.gtkw$/_filter/;
}

parse_verilog();
generate_gtkw_file();
    
exit (0);

#############
# Help text #
#############
sub help {
    printf("usage: %s -top <module> -trace <trace file> -gtkw <gtkw file> [verilog parser options]\n", $0);
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
# Generate GTKW file #
#######################
sub generate_gtkw_file {
    #Time
    my $sec;
    my $min;
    my $hour;
    my $mday;
    my $mon;
    my $year;
    my $wday;
    my $yday;
    my $isdst;
    my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
    my @days   = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
        
    #Only act if GTKW file is requested
    if ($gtkw_name) {
	my $out_handle = IO::File->new;
	$out_handle->open(">$gtkw_name") or die "Can't open $gtkw_name\n";

	#Print header
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
        $out_handle->printf("[*]\n");
        $out_handle->printf("[*] WbXbc GTKW file generator\n");
        $out_handle->printf("[*] %3s, %3s %.2d %4d\n", $days[$wday], 
			                               $months[$mon], 
			                               $mday, 
			                               $year);
        $out_handle->printf("[*]\n");

	#Print trace file information
	#Only act if trace file is given
	if ($trace_name) {
	    my @stats = stat($trace_name);
	    my $mtime = $stats[9];
	    my $size  = $stats[7];
	    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
	    $year += 1900;
            $out_handle->printf("[dumpfile] \"%s\"\n", $trace_name);
            #$out_handle->printf("[dumpfile_mtime] %3s %3s %.2d %.2d:%2d:%2d %4d\n", $days[$wday], 
            $out_handle->printf("[dumpfile_mtime] \"%3s %3s %.2d %.2d:%2d:%2d %4d\"\n", $days[$wday], 
				                                                        $months[$mon], 
				                                                        $mday, 
				                                                        $hour, 
				                                                        $min, 
				                                                        $sec, 
				                                                        $year);
            $out_handle->printf("[dumpfile_size] %d\n", $size);
	    if ($trace_name =~ /\.vcd$/) {
		$out_handle->printf("[optimize_vcd]\n");
	    }
	}

	#Print save file information
	$out_handle->printf("[savefile] \"%s\"\n", $gtkw_name);

	#Print window information
            $out_handle->printf("[timestart] 0\n");
            $out_handle->printf("[size] 1000 600\n");
            $out_handle->printf("[pos] -1 -1\n");
            $out_handle->printf("*-4.935745 6 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1\n");
            $out_handle->printf("[treeopen] %s.\n", $top_mod_name);
            $out_handle->printf("[sst_width] 210\n");
            $out_handle->printf("[signals_width] 150\n");
            $out_handle->printf("[sst_expanded] 1\n");
            $out_handle->printf("[sst_vpaned_height] 154\n");	

#========================================================================================================================
# Project specific code!!! Modify this code section when porting this script to another project!
	
	#Add SYSCON signals
	add_group($out_handle,
		  "SYSCON",
		  $top_mod_ref,
		  $top_mod_name,
		  [["async_rst_i"],
		   ["sync_rst_i"],
		   ["clk_i"],
		   ["itr_clk_i"],
		   ["tgt_clk_i"]],
		  1);

	#Add program bus
	if ((my $adr_ref  = $top_mod_ref->find_net("pbus_adr_o")) &&
	    (my $wdat_ref = $top_mod_ref->find_net("pbus_dat_o")) &&
	    (my $rdat_ref = $top_mod_ref->find_net("pbus_dat_i"))) {

	    my $adr_width  = int((num($adr_ref->msb)  - num($adr_ref->lsb))  + 1);	 
	    my $wdat_width = int((num($wdat_ref->msb) - num($wdat_ref->lsb)) + 1);	 
	    my $rdat_width = int((num($rdat_ref->msb) - num($rdat_ref->lsb)) + 1);	 

	    add_group($out_handle,
		      "PBUS",
		      $top_mod_ref,
		      $top_mod_name,
		      [["pbus_cyc_o"],
		       ["pbus_stb_o"],
		       ["pbus_we_o"],
		       ["pbus_adr_o",   ($adr_width-1),  0],
		       ["pbus_dat_o",   ($wdat_width-1), 0],
		       ["pbus_tga_cof_jmp_o"],
		       ["pbus_tga_cof_cal_o"],
		       ["pbus_tga_cof_bra_o"],
		       ["pbus_tga_cof_eow_o"],
		       ["pbus_tga_dato"],
		       ["pbus_tga_i"],
		       ["pbus_ack_i"],
		       ["pbus_err_i"],
		       ["pbus_rty_i"],
		       ["pbus_stall_i"],
		       ["pbus_dat_i",  ($rdat_width-1), 0]],
		      1);
	}
	
	#Add stack bus
	if ((my $adr_ref  = $top_mod_ref->find_net("sbus_adr_o")) &&
	    (my $wdat_ref = $top_mod_ref->find_net("sbus_dat_o")) &&
	    (my $rdat_ref = $top_mod_ref->find_net("sbus_dat_i"))) {

	    my $adr_width  = int((num($adr_ref->msb)  - num($adr_ref->lsb))  + 1);	 
	    my $wdat_width = int((num($wdat_ref->msb) - num($wdat_ref->lsb)) + 1);	 
	    my $rdat_width = int((num($rdat_ref->msb) - num($rdat_ref->lsb)) + 1);	 

	    add_group($out_handle,
		      "SBUS",
		      $top_mod_ref,
		      $top_mod_name,
		      [["sbus_cyc_o"],
		       ["sbus_stb_o"],
		       ["sbus_we_o"],
		       ["sbus_adr_o",   ($adr_width-1),  0],
		       ["sbus_dat_o",   ($wdat_width-1), 0],
		       ["sbus_tga_ps_o"],
		       ["sbus_tga_rs_o"],
		       ["sbus_ack_i"],
		       ["sbus_err_i"],
		       ["sbus_rty_i"],
		       ["sbus_stall_i"],
		       ["sbus_dat_i",  ($rdat_width-1), 0]],
		      1);
	}

	#Add SYSCON signals
	add_group($out_handle,
		  "IRQ",
		  $top_mod_ref,
		  $top_mod_name,
		  [["irq_ack_o"],
		   ["irq_req_i", 15, 0]],
		  1);
	
	#Add remaining probe signals
	add_block_signals($out_handle,
			  $top_mod_ref,
			  $top_mod_name);
	    
#========================================================================================================================

	#Print footer
        $out_handle->printf("[pattern_trace] 1\n");
        $out_handle->printf("[pattern_trace] 0\n");
	    
	$out_handle->close();
    }
}

sub add_block_signals {
    my $out_handle     = shift;
    my $parent_mod_ref = shift;
    my $inst_path      = shift;
 
    #Add signal group
    my $parent_name    = $parent_mod_ref->name;    
    add_group($out_handle,
	      $parent_name,
	      $parent_mod_ref,
	      $inst_path,
	      [["state_reg", "STATE"]],
	      0);

    #Parse child blocks
    my @cell_refs = $parent_mod_ref->cells_sorted();
    foreach my $cell_ref (@cell_refs) {	
	my $inst_name = $cell_ref->name;
	my $mod_ref   = $cell_ref->submod;
	#printf("%s: %s\n", $inst_name, $inst_path);
	add_block_signals($out_handle, $mod_ref, sprintf("%s.%s", $inst_path, $inst_name));
    }
}

sub add_group {
    my $out_handle  = shift;
    my $group_name  = shift;
    my $mod_ref     = shift;
    my $inst_name   = shift;
    my $net_list    = shift;
    my $is_open     = shift;

    my $net_cnt     = 0;
    my @net_out     = ();
    
    #check signals
    my $net_disp = "none"; 
    foreach my $net_entry (@$net_list) {
	my $entry_name = $net_entry->[0];
  	#Check net name
	if (my $net_ref   = $mod_ref->find_net($entry_name)) {
	    my $net_msb   = num($net_ref->msb);
	    my $net_lsb   = num($net_ref->lsb);
	    if ($net_msb < $net_lsb) {
		$net_msb   = num($net_ref->lsb);
		$net_lsb   = num($net_ref->msb);
	    }
	    my $net_width = abs(($net_msb - $net_lsb) + 1);
	    my $entry_msb  = $net_msb;
	    my $entry_lsb  = $net_lsb;
	    if ($#$net_entry == 2) {
		$entry_msb = $net_entry->[1];
		$entry_lsb = $net_entry->[2];
	    }
	    #printf("%s[%d:%d]\n", $entry_name, $net_msb, $net_lsb);
	    #Filtered signals
	    my $filter_name;
	    if ($#$net_entry == 1) {
		my $filter_prefix  = $net_entry->[1];
		my %filter_aliases = ();
		#Parse parameters for aliases
		foreach my $param_ref ($mod_ref->nets()) {
		    if ($param_ref->decl_type eq "parameter") {
			#printf("%s: %s (%s)\n", $param_ref->name, $param_ref->decl_type, $param_ref->value);
			if ($param_ref->name =~ /$filter_prefix\_(.+)$/) {
			    my $filter_alias = $1;
			    if ($param_ref->value =~ /'b([01]+)/) {
				my $filter_value = $1;
				if (length($filter_value) == $net_width) {
				    #Valid alias found 
				    $filter_aliases{$filter_value} = $filter_alias;
				    #printf("%s ->  %s\n", $filter_alias, $filter_value);
				}
			    }
			}
		    }
		}
		#Create uniqie ID
		my $id = "";
		foreach my $value (sort keys %filter_aliases) {
		    $id .= sprintf("%s:%s.", $value, $filter_aliases{$value});
		    #printf("%s:%s.", $value, $filter_aliases{$value});
		}
		#printf("id: %s\n", $id);
		if ($id ne "") {
		    #Check if filter already exists 
		    if (exists $filters{$id}) {
			#Reuse filter
			$filter_name = $filters{$id};
		    } else {
			#Create filter
			$filter_name = sprintf("%s_%.2d.txt", $filter_basename, $filter_cnt++);
			my $filter_handle  = IO::File->new;
			$filter_handle->open(">$filter_name") or die "Can't open $filter_name\n";
			foreach my $value (sort keys %filter_aliases) {
			    $filter_handle->printf("%s %s\n", $value, $filter_aliases{$value});
			    #printf("%s %s\n", $value, $filter_aliases{$value});
			}
			$filter_handle->close();
			$filters{$id} = $filter_name;
			$filter_name  = $filter_name;
		    }
		    #Add signal with filter
		    if ($net_disp ne "\@2029") {
			$net_disp = "\@2029";
			push(@net_out, $net_disp);
		    }
		    push(@net_out, sprintf("^1 %s",$filter_name));
		    if ($net_width == 1) {
			push(@net_out, sprintf("%s.%s", $inst_name, $entry_name));
		    } else {
			push(@net_out, sprintf("%s.%s[%d:%d]", $inst_name, $entry_name, $net_msb, $net_lsb));
		    }
		    $net_cnt++;
		    next;
		}
	    }  
	    #Single bit signals
	    if ($net_width == 1) {
		if ($net_msb == 0) {
		    #Plain signal 
		    if ($net_disp ne "\@28") {
			$net_disp = "\@28";
			push(@net_out, $net_disp);
		    }
		    push(@net_out, sprintf("%s.%s", $inst_name, $entry_name));		    
		} else {
		    #Aliased signal
		    if ($net_disp ne "\@29") {
			$net_disp = "\@29";
			push(@net_out, $net_disp);
		    }
		    push(@net_out, sprintf("+{%s.%s[%d]} %s.%s", $inst_name, $entry_name, $net_msb, $inst_name, $entry_name));
		}
		$net_cnt++;
		next;
	    }
	    #Multi-bit signals without offtset
	    if (($net_width >  1) &&
		($net_lsb   == 0)) {
		if ($entry_msb == $entry_lsb) { 
		    if ($net_disp ne "\@28") {
			$net_disp = "\@28";
			push(@net_out, $net_disp);
		    }
		} else {		    
		    if ($net_disp ne "\@22") {
			$net_disp = "\@22";
			push(@net_out, $net_disp);
		    }
		}
		
		if (($entry_msb >= $net_msb) &&
		    ($entry_lsb == 0)) {		    
		    #Plain signal 
		    push(@net_out, sprintf("%s.%s[%d:0]", $inst_name, $entry_name, $net_msb));
		} else {
		    #Compound signal
		    my $long_line = sprintf("#{%s.%s[%d", $inst_name, $entry_name, $entry_msb);
		    if ($entry_msb != $entry_lsb) {
			$long_line .= sprintf(":%d", $entry_lsb);
		    }
		    $long_line .= "]}";
		    for (my $i=$entry_msb; $i>=$entry_lsb; $i--) {
			$long_line .= sprintf(" (%d)%s.%s[%d:%d]", ($net_width - $i - 1),
					                            $inst_name,
					                            $entry_name,
					                            $net_msb,
					                            $net_lsb);
		    }
		    push(@net_out, $long_line);
		    #push(@net_out, "\@28");
		    #for (my $i=$entry_msb; $i>=$entry_lsb; $i--) {
		    #	push(@net_out, sprintf("(%d) %s.%s[%d:%d]", ($net_width - $i - 1),
		    #			                             $inst_name,
		    #			                             $entry_name,
		    #			                             $net_msb,
		    #			                             $net_lsb));
		    #}
                    #push(@net_out, "@1401200");
                    #push(@net_out, "-group_end");
		}
		$net_cnt++;
		next;
	    }
	    #Multi-bit signals with offtset
	    if ($net_width >  1) {		
		#Compound signal
		if ($entry_msb == $entry_lsb) { 
		    if ($net_disp ne "\@28") {
			$net_disp = "\@28";
			push(@net_out, $net_disp);
		    }
		} else {		    
		    if ($net_disp ne "\@22") {
			$net_disp = "\@22";
			push(@net_out, $net_disp);
		    }
		}
		
		my $long_line = sprintf("#{%s.%s[%d", $inst_name, $entry_name, $entry_msb);
		if ($entry_msb != $entry_lsb) {
		    $long_line .= sprintf(":%d", $entry_lsb);
		}
		$long_line .= "]}";
		for (my $i=$entry_msb; $i>=$entry_lsb; $i--) {
		    $long_line .= sprintf(" (%d)%s.%s[%d:0]", (($net_width-1) - $i),
					                      $inst_name,
					                      $entry_name,
					                      ($net_msb - $net_lsb));
		}
		$net_cnt++;
		next;
	    }
	}
    }

    #printf("net_cnt: %d\n", $net_cnt);
    if ($net_cnt > 0) {
	#printf("net_cnt: %d\n", $net_cnt);
	#Add grout header
	$out_handle->printf("\@%s\n", $is_open ? "800200" : "c00200");
	$out_handle->printf("-%s\n", $group_name);
	#Add signals
	foreach my $line (@net_out) {
	    $out_handle->print($line . "\n");
	}
	#Add grout footer
	$out_handle->printf("\@%s\n", $is_open ? "1000200" : "1401200");
	$out_handle->printf("-%s\n", $group_name);
    }
}

sub num {
    my $arg = shift;
    return(int((eval($arg))));
}

1;
