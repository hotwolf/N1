###############################################################################
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
#   This is the core of the N1 assembler, based on the HSW12 assembler        #
#   (https://github.com/hotwolf/HSW12).                                       #
###############################################################################
=pod
=head1 NAME

N1asm - N1 Assembler

=head1 SYNOPSIS

 require N1asm

 $asm = N1asm->new(\@source_files, \@library_dirs, \%assembler_defines, $cpu, $verbose);
 print FILEHANDLE $asm->print_listing();
 print FILEHANDLE $asm->print_mem();

=head1 REQUIRES

perl5.005, File::Basename, FindBin, Text::Tabs

=head1 DESCRIPTION

This module provides subroutines to...

=over 4

 - compile N1 assembler source code
 - create code lisings
 - create Verilog readmemh file
 - create symbol file

=back

=head1 METHODS

=head2 Creation

=over 4

=item N1asm->new(\@source_files, \@library_dirs, \%assembler_defines, $verbose)

 Creates and returns an N1asm object.
 This method requires five arguments:
     1. \@source_files:      a list of files to compile (array reference)
     2. \@library_dirs:      a list of directories to search include files in (array reference)
     3. \%assembler_defines: assembler defines to set before compiling the source code (hash reference)
     4. $cpu:                the target CPU ("HC11", "HC12"/"S12", "S12X", "XGATE") (string)
     5. $verbose:            switch to enable progress messages (boolean)

=back

=head2 Outputs

=over 4

=item $asm_object->print_listing()

 Returns the listing of the assembler source code (string).

=item $asm_object->print_mem()

 Returns a memory load file in Verilog readmemh format.

=head2 Misc

=over 4

=item $asm_object->reload(boolean)
 This method requires one argument:
     1. $verbose:  switch to enable progress messages (boolean)

 Recompiles the source code files.

=item $asm_object->$evaluate_expression($expr, $pc_global, $pc_local, $loc)

 Converts an expression into an integer and resolves compiler symbols.
 This method requires four arguments:
     1. $expr:   expression (string)
     2. $pc_global: current global program counter (integer)
     3. $pc_local: current local program counter (integer)
     4. $loc:    current "LOC" count (integer)

=back

=head1 AUTHOR

Dirk Heisswolf

=head1 VERSION HISTORY

=item V00.00 - Feb 28, 2024

 initial release

=cut

#################
# Perl settings #
#################
#use warnings;
#use strict;

####################
# create namespace #
####################
package N1asm;

###########
# modules #
###########
use IO::File;
use Fcntl;
use Text::Tabs;
use File::Basename;

####################
# global variables #
####################
#@source_files     (array)
#@libraies         (array)
#@initial_defs     (hash)
#$problems         (boolean)
#@code             (array)
#%precomp_defs     (hash)
#%comp_symbols     (hash)
#%global_addrspace (hash)
#%local_addrspace  (hash)
#$compile_count    (integer)
#$verbose          (boolean)

#############
# constants #
#############
################################
# Max. number of compile runs) #
################################
#*max_comp_runs = \200;
*max_comp_runs = \4;

###########
# version #
###########
*version = \"00.00";#"

###################
# path delimeters #
###################
if ($^O =~ /MSWin/i) {
    $path_del         = "\\";
    *path_absolute    = \qr/^[A-Z]\:/;
} else {
    $path_del         = "\/";
    *path_absolute    = \qr/^\//;
}

########################
# code entry structure #
########################
*code_entry_line   =    \0;
*code_entry_file   =    \1;
*code_entry_code   =    \2;
*code_entry_label  =    \3;
*code_entry_opcode =    \4;
*code_entry_args   =    \5;
*code_entry_global_pc = \6;
*code_entry_local_pc =  \7;
*code_entry_hex    =    \8;
*code_entry_words  =    \9;
*code_entry_errors =    \10;
*code_macros       =    \11;
*code_sym_tabs     =    \12;

###########################
# precompiler expressions #
###########################
*precomp_directive    = \qr/^\#(\w+)\s*(\S*)\s*(.*)\s*(?:;;)?/;  #$1:directive $2:name $3:value
*precomp_define       = \qr/define/i;
*precomp_undef        = \qr/undef/i;
*precomp_ifdef        = \qr/ifdef/i;
*precomp_ifndef       = \qr/ifndef/i;
*precomp_ifmac        = \qr/ifmac/i;
*precomp_ifnmac       = \qr/ifnmac/i;
*precomp_if           = \qr/if/i;
#*precomp_ifcpu       = \qr/ifcpu/i;
#*precomp_ifncpu      = \qr/ifncpu/i;
*precomp_else         = \qr/else/i;
*precomp_endif        = \qr/endif/i;
*precomp_include      = \qr/include/i;
*precomp_macro        = \qr/macro/i;
*precomp_emac         = \qr/emac/i;
*precomp_blanc_line   = \qr/^\s*$/;
*precomp_comment_line = \qr/^\s*;;/;
#*precomp_opcode      = \qr/^([^\#][\\\w]*\`?):?\s*([\w\.]*)\s*([^;]*)\s*[;\*]?/;  #$1:label $2:opcode $3:arguments
*precomp_opcode       = \qr/^([^\#][\w]*\`?):?\s*(\S*)\s*([^;]*\s*(?:;\s|;$)?)\s*(?:;;)?/;   #$1:label $2:opcode $3:arguments

############################
# address mode expressions #
############################
#operands
#*del                  = \qr/\s*/;
*del                   = \qr/\s*[\s,]\s*/;
*op_expr               = \qr/([^\"\'\s\,\<\>\[][^\"\'\s\,]*\'?|\".*\"|\'.*\'|\(.*\))/i;
*op_psop               = \qr/$op_expr/i;                                                                #$1:operand
*op_stack              = \qr/(<-|->|\s+)PS3(<-|->|<>|\s+)PS2(<-|->|<>|\s+)PS1(<-|->|<>|\s+)PS0(<-|->|<>|\s+)RS0(<-|->|\s+)/i;

#N1 address modes
*amod_n1_inh          = \qr/^\s*(;?)\s*$/i;                   #$1:semicolon
*amod_n1_abs14        = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:address $2:semicolon
*amod_n1_rel13        = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:address $2:semicolon
*amod_n1_uimm5        = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:data	  $2:semicolon
*amod_n1_simm5        = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:data	  $2:semicolon
*amod_n1_oimm5        = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:data	  $2:semicolon
*amod_n1_lit          = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:data	  $2:semicolon
*amod_n1_stack        = \qr/^\s*$op_stack\s*(;?)\s*$/i;       #$1:data    $2:semicolon
*amod_n1_mem          = \qr/^\s*$op_expr\s*(;?)\s*$/i;        #$1:address $2:semicolon

##############################
# pseudo opcocde expressions #
##############################
*psop_no_arg      = \qr/^\s*$/i; #
*psop_1_arg       = \qr/^\s*$op_psop\s*$/i; #$1:arg
*psop_2_args      = \qr/^\s*$op_psop$del$op_psop\s*$/i; #$1:arg $2:arg
*psop_3_args      = \qr/^\s*$op_psop$del$op_psop$del$op_psop\s*$/i; #$1:arg $2:arg $3:arg
*psop_string      = \qr/^\s*(.+)\s*$/i; #$1:string

#######################
# operand expressions #
#######################
*op_keywords           = \qr/^\s*(;)\s*$/i; #$1: keyword
*op_unmapped           = \qr/^\s*UNMAPPED\s*$/i;
*op_oprtr              = \qr/\-|\+|\*|\/|%|&|\||~|<<|>>/;
*op_no_oprtr           = \qr/[^\-\+\/%&\|~<>\s]/;
*op_term               = \qr/\%[01]+|[0-9]+|\$[0-9a-fA-F]+|\"(\w)\"|\*|\@/;
*op_binery             = \qr/^\s*([~\-]?)\s*\%([01_]+)\s*$/; #$1:complement $2:binery number
*op_dec                = \qr/^\s*([~\-]?)\s*([0-9_]+)\s*$/; #$1:complement $2:decimal number
*op_hex                = \qr/^\s*([~\-]?)\s*\$([0-9a-fA-F_]+)\s*$/; #$1:complement $2:hex number
*op_ascii              = \qr/^\s*([~\-]?)\s*[\'\"](.+)[\'\"]\s*$/; #$1:complement $2:ASCII caracter
*op_symbol             = \qr/^\s*([~\-]?)\s*([\w]+[\`]?)\s*$/; #$1:complement $2:symbol
#*op_symbol            = \qr/^\s*([~\-]?)\s*([\w]+[\`]?|[\`])\s*$/; #$1:complement $2:symbol
*op_curr_global_pc     = \qr/^\s*([~\-]?)\s*\@\s*$/;
*op_curr_local_pc       = \qr/^\s*([~\-]?)\s*\*\s*$/;
*op_formula            = \qr/^\s*($op_psop)\s*$/; #$1:formula
*op_formula_pars       = \qr/^\s*(.*)\s*\(\s*([^\(\)]+)\s*\)\s*(.*)\s*$/; #$1:leftside $2:inside $3:rightside
*op_formula_complement = \qr/^\s*([~\-])\s*([~\-].*)\s*$/; #$1:leftside $2:rightside
*op_formula_and        = \qr/^\s*([^\&]*)\s*\&\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_or         = \qr/^\s*([^\|]*)\s*\|\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_exor       = \qr/^\s*([^\^]*)\s*\^\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_rightshift = \qr/^\s*([^>]*)\s*>>\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_leftshift  = \qr/^\s*([^<]*)\s*<<\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_mul        = \qr/^\s*(.*$op_no_oprtr)\s*\*\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_div        = \qr/^\s*([^\/]*)\s*\/\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_mod        = \qr/^\s*(.*$op_no_oprtr)\s*\%\s*(.*)\s*$/; #$1:leftside $2:rightside
*op_formula_plus       = \qr/^\s*([^\+]*)\s*\+\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_formula_minus      = \qr/^\s*(.*$op_no_oprtr)\s*\-\s*(.+)\s*$/; #$1:leftside $2:rightside
*op_whitespace         = \qr/^\s*$/;

########################
# compiler expressions #
########################
*cmp_no_hexcode        = \qr/^\s*(.*?[^0-9a-fA-F\ ].*?)\s*$/; #$1:string

#############
# cpu types #
#############
*cpu_n1                 = \qr/^\s*N1\s*$/i;

#################
# opcode tables #
#################

#N1:            MNEMONIC      ADDRESS MODE                                              OPCODE
*opctab_n1 =   \{"!"       => [[$amod_n1_inh,           \&check_n1_inh,                 "02FF"],                                          #INH
                               [$amod_n1_mem,           \&check_n1_mem,                 "0200"]],                                         #mem
                 "*"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0E00"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0E00"]],                                         #UIMM5
                 "+"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0C00"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0C00"]],                                         #UIMM5
                 "+!"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0403 03FF 0C00 0755 02FF"]],                     #INH
                 "-"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0C60"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0C40"]],                                         #UIMM5
                 "0<"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0DF0"]],                                         #INH
                 "0<>"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0D70"]],                                         #INH
                 "0>"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0DB0"]],                                         #INH
                 "0="      => [[$amod_n1_inh,           \&check_n1_inh,                 "0D30"]],                                         #INH
	         "1+"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0C01"]],                                         #INH
	         "1-"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0C0F"]],                                         #INH
	         "2!"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0750 0460 02FF 0C01 02FF"]],                     #INH
	         "2*"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0F41"]],                                         #INH
	         "2/"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0f01"]],                                         #INH
	         "2@"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0750 0C01 03FF 0418 03FF"]],                     #INH
	         "2DROP"   => [[$amod_n1_inh,           \&check_n1_inh,                 "06A8 06A8"]],                                    #INH
	         "2DUP"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0758 0758"]],                                    #INH
	         "2OVER"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0750 0460 0758 0460"]],                          #INH
	         "2>R"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "06AB 06AB"]],                                    #INH
	         "2R>"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0755 0755"]],                                    #INH
	         "2R@"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "0755 0757"]],                                    #INH
	         "2ROT"	   => [[$amod_n1_inh,           \&check_n1_inh,                 "06AB 0580 06AB 0598 0755 0598 0755 0598 0460"]], #INH
	         "2SWAP"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0460 0598 0460"]],                               #INH
	         ";"       => [[$amod_n1_inh,           \&check_n1_inh,                 "8400"]],                                         #INH
	         "<"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0DA0"],                                          #INH
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0DA0"]],                                         #OIMM5
	         "<>"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0D40"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0D40"],                                          #UIMM5
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0D40"]],                                         #OIMM5
	         "="       => [[$amod_n1_inh,           \&check_n1_inh,                 "0D00"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0D00"],                                          #UIMM5
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0D00"]],                                         #OIMM5
	         ">"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0DE0"],                                          #INH
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0DE0"]],                                         #OIMM5
	         ">R"      => [[$amod_n1_inh,           \&check_n1_inh,                 "06AB"]],                                         #INH
	         "?DUP"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0750 0D30 2001 06A8"]],                          #INH
	         "@"       => [[$amod_n1_inh,           \&check_n1_inh,                 "03FF"],                                          #INH
                               [$amod_n1_mem,           \&check_n1_mem,                 "0300"]],                                         #mem
	         "ABS"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0C30"]],                                         #INH
	         "AND"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0E80"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0EC0"]],                                         #UIMM5
	         "BL"      => [[$amod_n1_inh,           \&check_n1_inh,                 "1020"]],                                         #INH
	         "BRANCH"  => [[$amod_n1_rel13,         \&check_n1_rel13,               "2000"]],                                         #REL13
	         "CALL"    => [[$amod_n1_inh,           \&check_n1_inh,                 "4000"],                                          #INH
	                       [$amod_n1_abs14,         \&check_n1_abs14,               "4000"]],                                         #ABS14
                 "CELL+"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0C01"]],                                         #INH
                 "CLRPS"   => [[$amod_n1_inh,           \&check_n1_inh,                 "1000 0000"]],                                    #INH
	         "CLRRS"   => [[$amod_n1_inh,           \&check_n1_inh,                 "1000 0001"]],                                    #INH
	         "DEPTH"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0100"]],                                         #INH
	         "DROP"    => [[$amod_n1_inh,           \&check_n1_inh,                 "06A8"]],                                         #INH
	         "DUP"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0750"]],                                         #INH
	         "EKEY"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0107"]],                                         #INH
	         "EKEY?"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0104"]],                                         #INH
	         "EMIT"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0005"]],                                         #INH
	         "EMIT?"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0105"]],                                         #INH
	         "EXECUTE" => [[$amod_n1_inh,           \&check_n1_inh,                 "7FFF"]],                                         #INH
	         "FALSE"   => [[$amod_n1_inh,           \&check_n1_inh,                 "1000"]],                                         #INH
                 "I"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0754"]],                                         #INH
	         "IDIS"    => [[$amod_n1_inh,           \&check_n1_inh,                 "1000 0003"]],                                    #INH
                 "IEN"     => [[$amod_n1_inh,           \&check_n1_inh,                 "1FFF 0003"]],                                    #INH
	         "IEN?"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0103"]],                                         #INH
	         "INVERT"  => [[$amod_n1_inh,           \&check_n1_inh,                 "0EBF"]],                                         #INH
	         "J"       => [[$amod_n1_inh,           \&check_n1_inh,                 "0755 0407"]],                                    #INH
	         "JUMP"    => [[$amod_n1_inh,           \&check_n1_inh,                 "C000"],                                          #INH
	                       [$amod_n1_abs14,         \&check_n1_abs14,               "C000"]],                                         #ABS14
                 "LITERAL" => [[$amod_n1_lit,           \&check_n1_lit,                 "1000"]],                                         #LIT
                 "LSHIFT"  => [[$amod_n1_inh,           \&check_n1_inh,                 "0F20"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0F20"]],                                         #UIMM5
                 "M*"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0A40"],                                          #INH
                               [$amod_n1_simm5,         \&check_n1_simm5,               "0A40"]],                                         #SIMM5
                 "M+"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0800"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0800"]],                                         #UIMM5
	         "MAX"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0CA0"],                                          #INH
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0CA0"]],                                         #OIMM5
                 "MIN"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0CE0"],                                          #INH
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0CE0"]],                                         #OIMM5
                 "NEGATE"  => [[$amod_n1_inh,           \&check_n1_inh,                 "0C70"]],                                         #INH
	         "NIP"     => [[$amod_n1_inh,           \&check_n1_inh,                 "06A0"]],                                         #INH
                 "OR"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0EC0"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0EC0"]],                                         #UIMM5
                 "OVER"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0758"]],                                         #INH
	         "PEEK"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0106"]],                                         #INH
	         "R>"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0755"]],                                         #INH
	         "R@"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0754"]],                                         #INH
                 "RDEPTH"  => [[$amod_n1_inh,           \&check_n1_inh,                 "0101"]],                                         #INH
                 "RSHIFT"  => [[$amod_n1_inh,           \&check_n1_inh,                 "0F00"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0F00"]],                                         #UIMM5
                 "ROT"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0460 0418"]],                                    #INH
	         "ROTX"    => [[$amod_n1_inh,           \&check_n1_inh,                 "041C"]],                                         #INH
	         "S>D"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0A41"]],                                         #INH
	         "STACK"   => [[$amod_n1_stack,         \&check_n1_stack,               "0400"]],                                         #STACK
                 "SWAP"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0418"]],                                         #INH
                 "SWAP-"   => [[$amod_n1_inh,           \&check_n1_inh,                 "0C40"],                                          #INH
                               [$amod_n1_oimm5,         \&check_n1_oimm5,               "0C60"]],                                         #OIMM5
	         "TRUE"    => [[$amod_n1_inh,           \&check_n1_inh,                 "1FFF"]],                                         #INH
                 "TUCK"    => [[$amod_n1_inh,           \&check_n1_inh,                 "0750 0460"]],                                    #INH
                 "TUCKX"   => [[$amod_n1_inh,           \&check_n1_inh,                 "07C0"]],                                         #INH
                 "U<"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0DC0"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0DC0"]],                                         #UIMM5
                 "U>"      => [[$amod_n1_inh,           \&check_n1_inh,                 "0D80"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0D80"]],                                         #UIMM5
                 "UM*"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0A00"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0A00"]],                                         #UIMM5
                 "XOR"     => [[$amod_n1_inh,           \&check_n1_inh,                 "0EA0"],                                          #INH
                               [$amod_n1_uimm5,         \&check_n1_uimm5,               "0EA0"]]};                                        #UIMM5

##################
# pseudo opcodes #
##################
#                   MNEMONIC       SUBROUTINE
*pseudo_opcodes = \{"ALIGN"    => \&psop_align,
                    "CPU"      => \&psop_cpu,
                    "DC.W"     => \&psop_dw,
                    "DS.W"     => \&psop_dsw,
                    "DW"       => \&psop_dw,
                    "ERROR"    => \&psop_error,
                    "EQU"      => \&psop_equ,
                    "FCC"      => \&psop_fcc,
                    "FCS"      => \&psop_fcs,
                    "FCZ"      => \&psop_fcz,
                    "FDB"      => \&psop_dw,
                    "FILL"     => \&psop_fill,
                    "FLET32"   => \&psop_flet32, #Fletcher-32 checksum generation
                    "LOC"      => \&psop_loc,
                    "ORG"      => \&psop_org,
                    "RMW"      => \&psop_dsw,
                    "UNALIGN"  => \&psop_unalign,
                    "SETDP"    => \&psop_setdp,
                    #legacy pseudo opcodes to ignore
                    "BSZ"      => \&psop_ignore,
                   #"CPU"      => \&psop_ignore,
                    "DB"       => \&psop_ignore,
                    "DC.B"     => \&psop_ignore,
                    "DS"       => \&psop_ignore,
                    "DS.B"     => \&psop_ignore,
                    "FCB"      => \&psop_ignore,
                    "RMB"      => \&psop_ignore,
                    "ZMB"      => \&psop_ignore,
                   #"SETDP"    => \&psop_ignore,
                    "NAME"     => \&psop_ignore,
                    "TTL"      => \&psop_ignore,
                    "VER"      => \&psop_ignore,
                    "VERSION"  => \&psop_ignore,
                    "PAG"      => \&psop_ignore,
                    "FUN"      => \&psop_ignore,
                    "FUNA"     => \&psop_ignore,
                    "END"      => \&psop_ignore};

###############
# constructor #
###############
sub new {
    my $proto            = shift @_;
    my $class            = ref($proto) || $proto;
    my $file_list        = shift @_;
    my $library_list     = shift @_;
    my $defines          = shift @_;
    my $cpu              = shift @_;
    my $verbose          = shift @_;
    my $symbols          = shift @_;
    my $self             = {};

    #initalize global variables
    $self->{source_files} = $file_list;
    $self->{libraries}    = $library_list;
    $self->{initial_defs} = $defines;
    $self->{precomp_defs} = $defines;
    $self->{cpu}          = $cpu;
    $self->{verbose}      = $verbose;

    #reset remaining global variables
    $self->{problems}         = "no code";
    $self->{code}             = [];
    $self->{comp_symbols}     = {};
    $self->{macros}           = {};
    $self->{macro_argcs}      = {};
    $self->{macro_symbols}    = {};
    $self->{global_addrspace} = {};
    $self->{local_addrspace}  = {};
    $self->{compile_count}    = 0;
    $self->{opcode_table}     = $opctab_n1;
    $self->{dir_page}         = 0xFF00;

    #instantiate object
    bless $self, $class;
    #printf STDERR "libs: %s\n", join(", ", @$library_list);
    
    #compile code
    $self->compile($file_list, [@$library_list, sprintf(".%s", $path_del)], $symbols);

    return $self;
}

##############
# destructor #
##############
#sub DESTROY {
#    my $self = shift @_;
#}

##########
# reload #
##########
sub reload {
    my $self         = shift @_;
    my $verbose      = shift @_;
    my $symbols      = $self->{comp_symbols};

    #reset global variables
    $self->{problems}         = "no code";
    $self->{code}             = [];
    $self->{precomp_defs}     = %{$self->{initial_defs}};
    $self->{comp_symbols}     = {};
    $self->{macros}           = {};
    $self->{macro_argcs}      = {};
    $self->{macro_symbols}    = {};
    $self->{global_addrspace} = {};
    $self->{local_addrspace}  = {};
    $self->{compile_count}    = 0;
    if (defined $verbose) {
        $self->{verbose}      = $verbose;
    }

    #compile code
    $self->compile($self->{source_files}, $self->{libraries}, $symbols);
}

###########
# compile #
###########
sub compile {
    my $self            = shift @_;
    my $file_list       = shift @_;
    my $library_list    = shift @_;
    my $initial_symbols = shift @_;
    #compile status
    my $old_undef_count;
    my $new_undef_count;
    my $redef_count;
    my $error_count;
    my $compile_count;
    my $keep_compiling;
    my $result_ok;
    #compiler runs
    #my $max_comp_runs = 200;

    ##############
    # precompile #
    ##############
    if (!$self->precompile($file_list, $library_list, [[1,1,1]], undef)) {
        #printf "precompiler symbols: %s\n", join("\n         ", keys %{$self->{comp_symbols}});
        #$self->{problems} = "precompiler";

        ##################################################
        # export precompiler defines to compiler symbols #
        ##################################################
        $self->export_precomp_defs();

        ###########
        # compile #
        ###########
        $self->{compile_count} = 0;
        $old_undef_count       = $#{$self->{code}};
        $redef_count           = 0;
        $keep_compiling        = 1;
        $result_ok             = 1;

        #print progress messages
        if ($self->{verbose}) {
            print STDOUT "\n";
            print STDOUT "COMPILE RUN  UNDEFINED SYMBOLS  REDEFINED SYMBOLS\n";
            print STDOUT "===========  =================  =================\n";
        }

        while ($keep_compiling) {
            $self->{compile_count} = ($self->{compile_count} + 1);
            #compile run
            ($error_count, $new_undef_count, $redef_count) = @{$self->compile_run()};
            #print progress messages
            if ($self->{verbose}) {
                printf STDOUT "%8d  %17d  %17d\n", $self->{compile_count}, $new_undef_count, $redef_count;
            }
	    
	    #initialize compiler symbols
	    if ($self->{compile_count} == 1) {
		$self->initialize_symbols($initial_symbols);
	    }

            #printf STDERR "compile run: %d\n", $self->{compile_count};
            #printf STDERR "errors:      %d\n", $error_count;
            #printf STDERR "old undefs:  %d\n", $old_undef_count;
            #printf STDERR "new undefs:  %d\n", $new_undef_count;
            #printf STDERR "redefs:      %d\n", $redef_count;
            #printf STDERR "symbols: \"%s\"\n", join("\", \"", keys %{$self->{comp_symbols}});;

            #################
            # check results #
            #################
            if ($error_count > 0) {
                ###################
                # compiler errors #
                ###################
                $keep_compiling = 0;
                $result_ok      = 0;
                if ($error_count == 1) {
                    $self->{problems} = "1 compiler error!";
                } else {
                    $self->{problems} = sprintf("%d compiler errors!", $error_count);
                }
            } elsif ($self->{compile_count} >= $max_comp_runs) {
                ##########################
                # too many compiler runs #
                ##########################
                $keep_compiling = 0;
                $result_ok      = 0;
                $self->{problems} = sprintf("%d assembler runs and no success!", $max_comp_runs);
            #} elsif (($new_undef_count > 0) &&
            #          ($new_undef_count >= $old_undef_count)) {
            #    ######################
            #    # unresolved opcodes #
            #    ######################
            #    $keep_compiling = 0;
            #    $result_ok     = 0;
            #    $self->{problems} = sprintf("%d undefined opcodes!", $new_undef_count);
            } elsif (($new_undef_count == 0) &&
                     ($redef_count     == 0)) {
                ##########################
                # compilation successful #
                ##########################
                $keep_compiling = 0;
                $result_ok      = 1;
                $self->{problems} = 0;
            }
            ##########################
            # update old undef count #
            ##########################
            $old_undef_count = $new_undef_count;
        }

        #####################################
        # see if compilation was successful #
        #####################################
        if ($result_ok) {
            ############################
            # determine address spaces #
            ############################
            $self->determine_addrspaces();
        }
    } else {
        $self->{problems} = "precompiler error";
    }
    #print "error_count   = $error_count\n";
    #print "undef_count   = $new_undef_count\n";
    #print "compile_count = $self->{compile_count}\n";

}

##############
# precompile #
##############
sub precompile {
    my $self         = shift @_;
    my $file_list    = shift @_;
    my $library_list = shift @_;
    my $ifdef_stack  = shift @_;
    my $macro        = shift @_;
    #file
    my $file_handle;
    my $file_name;
    my $library_path;
    my $file;
    #errors
    my $error;
    my $error_count;
    #CPU
    my $cpu = $self->{cpu};
    #line
    my $line;
    my $line_count;
    my $label;
    my $opcode;
    my $arguments;
    my $directive;
    my $arg1;
    my $arg2;
    #source code
    my @srccode_sequence;
    #temporary
    my $match;
    my $value;

    #############
    # file loop #
    #############
    foreach $file_name (@$file_list) {
        ############################
        # determine full file name #
        ############################
        #printf "file_name: %s\n", $file_name;
        $error = 0;
        if ($file_name =~ /$path_absolute/) {
	   #printf "absolute path: %s\n", $file_name;
           #absolute path
            $file = $file_name;
            if (-e $file) {
                if (-r $file) {
                   if ($file_handle = IO::File->new($file, O_RDONLY)) {
                    } else {
                        $error = sprintf("unable to open file \"%s\" (%s)", $file, $!);
                        #print "$error\n";
                    }
                } else {
                    $error = sprintf("file \"%s\" is not readable", $file);
                    #print "$error\n";
                }
            } else {
                $error = sprintf("file \"%s\" does not exist", $file);
                #print "$error\n";
            }
        } else {
	    #printf "relative path: %s\n", $file_name;
            #library path
            $match = 0;
            ################
            # library loop #
            ################
            #printf STDERR "PRECOMPILE: %s\n", join(":", @$library_list);
            foreach $library_path (@$library_list) {
                if (!$match && !$error) {
                    $file = sprintf("%s%s", $library_path, $file_name);
                    #printf STDERR "file: \"%s\"\n", $file;
                    if (-e $file) {
                        $match = 1;
                        if (-r $file) {
                            if ($file_handle = IO::File->new($file, O_RDONLY)) {
                            } else {
                                $error = sprintf("unable to open file \"%s\" (%s)", $file, $!);
                                #print "$error\n";
                            }
                        } else {
                            $error = sprintf("file \"%s\" is not readable", $file);
                            #print "$error\n";
                        }
                    }
                }
            }
            if (!$match) {
                $file  = $file_name;
                $error = sprintf("file \"%s\" does not exist in any library path", $file);
                #print "$error\n";
            }
        }
        #################
        # quit on error #
        #################
        if ($error) {
            #store error message
            push @{$self->{code}}, [undef,      #line count
                                    \$file,     #file name
                                    [],         #code sequence
                                    "",         #label
                                    "",         #opcode
                                    "",         #arguments
                                    undef,      #global pc
                                    undef,      #local pc
                                    undef,      #hex code
                                    undef,      #words
                                    [$error],   #errors
                                    undef,      #macros
				    undef];     #symbol tables
            return 1;
        }

        #reset variables
        $error            = 0;
        $error_count      = 0;
        $line_count       = 0;
        @srccode_sequence = ();
        #############
        # line loop #
        #############
        while ($line = <$file_handle>) {
            #trim line
            chomp $line;
            $line =~ s/\s*$//;

            #untabify line
            #print STDERR "before:  $line\n";
            $Text::Tabs::tabstop = 8;
            $line = Text::Tabs::expand($line);
            #print STDERR "after:   $line\n";

            #increment line count
            $line_count++;

            #printf "ifds: %d %d %d %d\n", ($#$ifdef_stack,
            #                              $ifdef_stack->[$#$ifdef_stack]->[0],
            #                              $ifdef_stack->[$#$ifdef_stack]->[1],
            #                              $ifdef_stack->[$#$ifdef_stack]->[2]);
            #printf "line: %s\n", $line;
            ##############
            # parse line #
            ##############
            for ($line) {
                ################
                # comment line #
                ################
                /$precomp_comment_line/ && do {
                    #print " => is comment\n";
                    #check ifdef stack
                    if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                        #store comment line
                        push @srccode_sequence, $line;
                    }
                    last;};
                ##########
                # opcode #
                ##########
                /$precomp_opcode/ && do {
                    #print " => is opcode\n";
                    #line =~  $precomp_opcode
                    $label     = $1;
                    $opcode    = $2;
                    $arguments = $3;
                    $label     =~ s/^\s*//;
                    $label     =~ s/\s*$//;
                    $opcode    =~ s/^\s*//;
                    $opcode    =~ s/\s*$//;
                    $arguments =~ s/^\s*//;
                    $arguments =~ s/\s*$//;

                    #printf STDERR " ===> \"%s\" \"%s\" \"%s\"\n", $label, $opcode, $arguments;
                    #printf STDERR "\"%s\" ->%s\n", $line, length($line);
                    #check ifdef stack
                    if ($ifdef_stack->[$#$ifdef_stack]->[0]){

			#Interpret pseudo opcode CPU
			if (uc($opcode) eq 'CPU') {
			    $cpu = uc($arguments);
			}

                        #store source code line
                        push @srccode_sequence, $line;
			if (defined $macro) {
			    push @{$self->{macros}->{$macro}}, [$line_count,          #line count
								\$file,               #file name
								[@srccode_sequence],  #code sequence
								$label,               #label
								$opcode,              #opcode
								$arguments,           #arguments
								undef,                #global pc
								undef,                #local pc
								undef,                #hex code
								undef,                #words
								0,                    #errors
								undef,                #macros
								undef];               #symbol tables

			    #add label to precompiler defines (makes N1 behave a little more like AS12)
			    if ($label =~ /\S/) {
				$self->{macro_symbols}->{uc($macro)}->{uc($label)} = undef;
			    }
			} else {
			    push @{$self->{code}}, [$line_count,          #line count
						    \$file,               #file name
						    [@srccode_sequence],  #code sequence
						    $label,               #label
						    $opcode,              #opcode
						    $arguments,           #arguments
						    undef,                #global pc
						    undef,                #local pc
						    undef,                #hex code
						    undef,                #words
						    0,                    #errors
						    undef,                #macros
						    undef];               #symbol tables

			    #add label to precompiler defines (makes N1 behave a little more like AS12)
			    if ($label =~ /\S/) {
				$self->{precomp_defs}->{uc($label)} = "";
				#if ($label =~ /^SCI/i) {printf " ===> \"%s\" \"%s\" \"%s\"\n", $label, $opcode, $arguments;}
			    }
			}
                        #reset code buffer
                        @srccode_sequence = ();
                    }
                    last;};
                ##############
                # blanc line #
                ##############
                /$precomp_blanc_line/ && do {
                    #print " => is blanc line\n";
                    #check ifdef stack
                    if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                        #store comment line
                        #push @srccode_sequence, "";
			#clear comment buffer
			@srccode_sequence = ();
                    }
                    last;};
                #########################
                # precompiler directive #
                #########################
                /$precomp_directive/ && do {
                    #print " => is precompiler directive\n";
                    #line =~  $precomp_directive
                    my $directive  = $1;
                    my $arg1       = $2;
                    my $arg2       = $3;
                    #printf "\"%s\" \"%s\" \"%s\"\n", $directive, $arg1, $arg2;

                    for ($directive) {
                        ##########
                        # define #
                        ##########
                        /$precomp_define/ && do {
                            #print "   => define\n";
                            #print "       $arg1 $arg2\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
				$self->{precomp_defs}->{uc($arg1)} = "";
				#printf "        ==> %s\n", $self->{precomp_defs}->{uc($arg1)};
                            }
                            last;};
                        #########
                        # undef #
                        #########
                        /$precomp_undef/ && do {
                            #print "   => undef\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if (exists $self->{precomp_defs}->{uc($arg1)}) {
                                    delete $self->{precomp_defs}->{uc($arg1)};
                                }
                            }
                            last;};
                        #########
                        # ifdef #
                        #########
                        /$precomp_ifdef/ && do {
                            #print "   => ifdef\n";
                            #printf "   => %s\n", join(", ", keys %{$self->{precomp_defs}});
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if (exists $self->{precomp_defs}->{uc($arg1)}) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        ##########
                        # ifndef #
                        ##########
                        /$precomp_ifndef/ && do {
                            #print "   => ifndef\n";
                            #printf "   => %s\n", join(", ", keys %{$self->{precomp_defs}});
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if (! exists $self->{precomp_defs}->{uc($arg1)}) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        #########
                        # ifmac #
                        #########
                        /$precomp_ifmac/ && do {
                            #print "   => ifmac\n";
                            #printf "   => %s\n", join(", ", keys %{$self->{macros}});
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if (exists $self->{macros}->{uc($arg1)}) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        ##########
                        # ifnmac #
                        ##########
                        /$precomp_ifnmac/ && do {
                            #print "   => ifnmac\n";
                            #printf "   => %s\n", join(", ", keys %{$self->{macros}});
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if (! exists $self->{macros}->{uc($arg1)}) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        #########
                        # ifcpu #
                        #########
                        /$precomp_ifcpu/ && do {
                            #print "   => ifcpu\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if ($cpu eq uc($arg1)) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        ##########
                        # ifncpu #
                        ##########
                        /$precomp_ifncpu/ && do {
                            #print "   => ifncpu\n";
                            #printf "   => %s\n", join(", ", keys %{$self->{macros}});
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                if ($cpu ne uc($arg1)) {
                                    push @$ifdef_stack, [1, 0, 1];
                                } else {
                                    push @$ifdef_stack, [0, 0, 1];
                                }
                            } else {
                                push @$ifdef_stack, [0, 0, 0];
                            }
                            last;};
                        ########
                        # else #
                        ########
                        /$precomp_else/ && do {
                            #print "   => else\n";
                            #check ifdef stack
                                if ($ifdef_stack->[$#$ifdef_stack]->[1]){
                                    #unexpected "else"
                                    $error = "unexpected \"#else\" directive";
                                    #print "   => ERROR! $error\n";
                                    #store source code line
                                    push @srccode_sequence, $line;
                                    #store error message
                                    push @{$self->{code}}, [$line_count,         #line count
                                                            \$file,              #file name
                                                            [@srccode_sequence], #code sequence
                                                            "",                  #label
                                                            "",                  #opcode
                                                            "",                  #arguments
                                                            undef,               #global pc
                                                            undef,               #local pc
                                                            undef,               #hex code
                                                            undef,               #words
                                                            [$error],            #errors
                                                            undef,               #macros
							    undef];              #symbol tables
                                    $file_handle->close();
                                    return ++$error_count;
                                } else {
                                    if ($ifdef_stack->[$#$ifdef_stack]->[2]){
                                        #set else-flag
                                        $ifdef_stack->[$#$ifdef_stack]->[1] = 1;
                                        #invert ifdef-flag
                                        $ifdef_stack->[$#$ifdef_stack]->[0] = (! $ifdef_stack->[$#$ifdef_stack]->[0]);
                                    }
                                }
                            last;};
                        #########
                        # endif #
                        #########
                        /$precomp_endif/ && do {
                            #print "   => endif\n";
                            #check ifdef stack
                            if ($#$ifdef_stack <= 0){
                                #unexpected "else"
                                $error = "unexpected \"#endif\" directive";
                                #print "   => ERROR! $error\n";
                                #store source code line
                                push @srccode_sequence, $line;
                                #store error message
                                push @{$self->{code}}, [$line_count,         #line count
                                                        \$file,              #file name
                                                        [@srccode_sequence], #code sequence
                                                        "",                  #label
                                                        "",                  #opcode
                                                        "",                  #arguments
                                                        undef,               #global pc
                                                        undef,               #local pc
                                                        undef,               #hex code
                                                        undef,               #words
                                                        [$error],            #errors
                                                        undef,               #macros
							undef];              #symbol tables
                                $file_handle->close();
                                return ++$error_count;
                            } else {
                                pop @$ifdef_stack;
                            }
                            last;};
                        ###########
                        # include #
                        ###########
                        /$precomp_include/ && do {
                            #print "   => include $arg1\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]) {
                                #precompile include file
                                #printf STDERR "INCLUDE: %s\n", join(":", (@$library_list, dirname($file_list->[0])));
                                $value = $self->precompile([$arg1], [@$library_list, sprintf("%s%s", dirname($file_list->[0]), $path_del)], $ifdef_stack, $macro);
                                if ($value) {
                                    $file_handle->close();
                                    return ($value + $error_count);
                                }
                            }
                            last;};
                        #########
                        # macro #
                        #########
                        /$precomp_macro/ && do {
			    #print "   => macro\n";
                            #print "       $arg1 $arg2\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
				if (defined $macro) {
                                    #unexpected "macro"
                                    $error = sprintf "unexpected \"#MACRO\" directive (no \"#EMAC\" for macro \"%s\")", uc($macro);
                                    #print "   => ERROR! $error\n";
                                    #store source code line
                                    push @srccode_sequence, $line;
                                    #store error message
                                    push @{$self->{code}}, [$line_count,         #line count
                                                            \$file,              #file name
                                                            [@srccode_sequence], #code sequence
                                                            "",                  #label
                                                            "",                  #opcode
                                                            "",                  #arguments
                                                            undef,               #global pc
                                                            undef,               #local pc
                                                            undef,               #hex code
                                                            undef,               #words
                                                            [$error],            #errors
                                                            undef,               #macros
							    undef];              #symbol tables
                                    $file_handle->close();
                                    return ++$error_count;
				} elsif (exists $self->{macros}->{uc($arg1)}) {
				    #macro redefined
                                    $error = sprintf "macro %s redefined", $arg1;
                                    #print "   => ERROR! $error\n";
                                    #store source code line
                                    push @srccode_sequence, $line;
                                    #store error message
                                    push @{$self->{code}}, [$line_count,         #line count
                                                            \$file,              #file name
                                                            [@srccode_sequence], #code sequence
                                                            "",                  #label
                                                            "",                  #opcode
                                                            "",                  #arguments
                                                            undef,               #global pc
                                                            undef,               #local pc
                                                            undef, ,             #hex code
                                                            undef,               #words
                                                            [$error],            #errors
                                                            undef,               #macros
							    undef];              #symbol tables
                                    $file_handle->close();
                                    return ++$error_count;
				} else {
				    ($error, $value) = @{$self->evaluate_expression($arg2, undef, undef, undef, undef)};
				    if (!defined $value) {
					#argument count undefined
					if (!$error) {
					    $error = "number of macro arguments not defined";
					}
					#print "   => ERROR! $error\n";
					#store source code line
					push @srccode_sequence, $line;
					#store error message
					push @{$self->{code}}, [$line_count,         #line count
								\$file,              #file name
								[@srccode_sequence], #code sequence
								"",                  #label
								"",                  #opcode
								"",                  #arguments
								undef,               #global pc
								undef,               #local pc
								undef,               #hex code
								undef,               #words
								[$error],            #errors
								undef,               #macros
								undef];              #symbol tables
					$file_handle->close();
					return ++$error_count;
				    } else {
					#define new macro
					$macro                           = uc($arg1);
					$self->{macro_symbols}->{$macro} = {}; 
					$self->{macro_argcs}->{$macro}   = $arg2;
					$self->{macros}->{$macro}        = [];
					#print "=> MACRO \"$macro\" defined\n";

				    }
				}
			    }
                            last;};
                        ########
                        # emac #
                        ########
                        /$precomp_emac/ && do {
			    #print "   => emac\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
				if (defined $macro) {
				    undef $macro;
				} else {
                                    #unexpected "emac"
                                    $error = "unexpected \"#EMAC\" directive";
                                    #print "   => ERROR! $error\n";
                                    #store source code line
                                    push @srccode_sequence, $line;
                                    #store error message
                                    push @{$self->{code}}, [$line_count,         #line count
                                                            \$file,              #file name
                                                            [@srccode_sequence], #code sequence
                                                            "",                  #label
                                                            "",                  #opcode
                                                            "",                  #arguments
                                                            undef,               #global pc
                                                            undef,               #local pc
                                                            undef,               #hex code
                                                            undef,               #words
                                                            [$error],            #errors
							    undef,               #macros
							    undef];              #symbol tables
                                    $file_handle->close();
                                    return ++$error_count;
				}
                            }
                            last;};
                        #################################
                        # invalid precompiler directive #
                        #################################
                        // && do {
                            #print "   => invalid precompiler directive\n";
                            #check ifdef stack
                            if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                                #unexpected "else"
                                $error = "invalid precompiler directive";
                                #store source code line
                                push @srccode_sequence, $line;
                                #store error message
                                push @{$self->{code}}, [$line_count,         #line count
                                                        \$file,              #file name
                                                        [@srccode_sequence], #code sequence
                                                        "",                  #label
                                                        "",                  #opcode
                                                        "",                  #arguments
                                                        undef,               #global pc
                                                        undef,               #local pc
                                                        undef,               #hex code
                                                        undef,               #words
                                                        [$error],            #errors
							undef,               #macros
							undef];              #symbol tables
				$file_handle->close();
				return ++$error_count;
                                #++$error_count;
                                #@srccode_sequence = ();
                            }
                        last;};
                    }
                    last;};

                ##################
                # invalid syntax #
                ##################
                // && do {
                    #print "   => invalid syntax\n";
                    #check ifdef stack
                    if ($ifdef_stack->[$#$ifdef_stack]->[0]){
                        #unexpected "else"
                        $error = "invalid syntax";
                        #store source code line
                        push @srccode_sequence, $line;
                        #store error message
                        push @{$self->{code}}, [$line_count,         #line count
                                                \$file,              #file name
                                                [@srccode_sequence], #code sequence
                                                "",                  #label
                                                "",                  #opcode
                                                "",                  #arguments
                                                undef,               #global pc
                                                undef,               #local pc
                                                undef,               #hex code
                                                undef,               #words
                                                [$error],            #errors
						undef,               #macros
						undef];              #symbol tables
			$file_handle->close();
			return ++$error_count;
                        #$error_count++;
                        #@srccode_sequence = ();
                    }
                    last;};
            }
        }
    }
    $file_handle->close();
    return $error_count;
}

#######################
# export_precomp_defs #
#######################
sub export_precomp_defs {
    my $self = shift @_;
    my $key;
    my $string;
    my $error;
    my $value;

    ###########################
    # precompiler define loop #
    ###########################
    foreach $key (keys %{$self->{precomp_defs}}) {
        $string = $self->{precomp_defs}->{uc($key)};
        #default value
        if (!defined $string) {
            #$string = "1";
            $string = undef;
        } elsif ($string =~ /^\s*$/) {
            #$string = "1";
            $string = undef;
        } else {
            printf "\"%s\" \"%s\" \n", $key, $string;
	}

        #check if symbol already exists
        if (! exists $self->{comp_symbols}->{uc($key)}) {

            if (!defined $string) {
                $error = 0;
                $value = undef;
            } else {
                ($error, $value) = @{$self->evaluate_expression($string, undef, undef, undef, undef)};
            }
            #export define
            $self->{comp_symbols}->{uc($key)} = $value;
            #printf "\"%s\" \"%s\" \"%s\"\n", $key, $string, $value;
        }
    }
}

######################
# initialize symbols #
######################
sub initialize_symbols {
    my $self    = shift @_;
    my $symbols = shift @_;   
    my $key;
    my $string;
    my $error;
    my $value;

    ###############
    # symbol loop #
    ###############
    foreach $key (keys %{$self->{comp_symbols}}) {
	if (! defined $self->{comp_symbols}->{$key}) {	
	    if (exists $symbols->{$key}) {
		if (defined $symbols->{$key}) {
		    $self->{comp_symbols}->{$key} = $symbols->{$key};
		    #printf STDERR "Importing: %s=%s\n",  $key, $symbols->{$key};
		}
	    }
	}
    }
    #foreach $key (keys %{$self->{comp_symbols}}) {
    #	printf STDERR "COMP: %s\n",  $key;
    #}
}

###############
# compile_run #
###############
sub compile_run {
    my $self          = shift @_;

    #code
    my $code_entry;
    my $code_label;
    my $code_opcode;
    my $code_args;
    my $code_pc_global;
    my $code_pc_local;
    my $code_hex;
    my $code_word_cnt;
    my $code_macros;
    my $code_sym_tab;
    my $code_sym_tab_key;
    my $code_sym_tab_val;
    my $code_sym_tabs;
    my $code_sym_tab_cnt;
    #opcode
    my $opcode_entries;
    my $opcode_entry;
    my $opcode_entry_cnt;
    my $opcode_entry_total;
    my $opcode_amode_expr;
    my $opcode_amode_check;
    my $opcode_amode_opcode;
    #macros
    my $macro_name;
    my @macro_args;
    my $macro_argc;
    my @macro_comments;
    my $macro_comment;
    my $macro_comment_replace;
    my $macro_comment_keep;
    my $macro_label;
    my $macro_label_replace;
    my $macro_opcode;
    my $macro_opcode_replace;
    my $macro_arg;
    my $macro_arg_replace;
    my $macro_hierarchy;
    my $macro_sym_tab;
    my $macro_sym_tabs;
    my $macro_symbol;
    my $macro_entries;
    my $macro_entry;
    my @macro_code_list;

    #label
    my @label_stack;
    my $prev_macro_depth;
    my $cur_macro_depth;

    my $label_value;
    my $label_ok;
    #program counters
    my $pc_global;
    my $pc_local;
    #loc count
    my $loc_cnt;
    #problem counters
    my $error_count;
    my $undef_count;
    my $redef_count;
    #temporary
    my $result;
    my $error;
    my $match;

    #######################
    # initialize counters #
    #######################
    $pc_global      = undef;
    $pc_local      = undef;
    $loc_cnt     = 0;
    $error_count = 0;
    $undef_count = 0;
    $redef_count = 0;

    #####################
    # reset labels hash #
    #####################
    @label_stack      = ({});
    $prev_macro_depth = 0;

    #####################
    # reset direct page #
    #####################
    $self->{dir_locale} = 0;

    #############
    # code loop #
    #############
    #print "compile_run:\n";

    #foreach $code_entry (@{$self->{code}}) {
    for ($code_entry_cnt = 0;
	 $code_entry_cnt <= $#{$self->{code}};
	 $code_entry_cnt++) {
	 $code_entry = $self->{code}->[$code_entry_cnt];
	
        $code_label     = $code_entry->[3];
        $code_opcode    = $code_entry->[4];
        $code_args      = $code_entry->[5];
        $code_pc_global = $code_entry->[6];
        $code_pc_local  = $code_entry->[7];
        $code_hex       = $code_entry->[8];
        $code_word_cnt  = $code_entry->[9];
        $code_macros    = $code_entry->[11];
        $code_sym_tabs  = $code_entry->[12];

        #printf STDERR "code_label     = %s\n", $code_label;
        #printf STDERR "code_opcode    = %s\n", $code_opcode;
        #printf STDERR "code_args      = %s\n", $code_args;
        #printf STDERR "code_pc_global = %s\n", $code_pc_global;
        #printf STDERR "code_pc_local  = %s\n", $code_pc_local;
        #printf STDERR "code_hex       = %s\n", $code_hex;
        #printf STDERR "code_word_cnt  = %s\n", $code_word_cnt;
        #printf STDERR "code_macros    = %s\n", $code_macros;
        #printf STDERR "code_sym_tabs  = %s\n", $code_sym_tabs;

        #print  STDERR "error_count = $error_count\n";
        #print  STDERR "undef_count = $undef_count\n";
	#if (defined $code_macros) {
	#    printf STDERR "%-8s %-8s %s (%s)\n", $code_label, $code_opcode, $code_args, join(",", @$code_macros);
	#} else {
	#    printf STDERR "%-8s %-8s %s\n", $code_label, $code_opcode, $code_args;
	#}
	#if (defined $code_sym_tabs) {
	#    printf "               sym_tabs defined: (%d)\n", ($#$code_sym_tabs+1);
	#    foreach $code_sym_tab (@{$code_sym_tabs}) {
	#	 print "               -> ";
	#	 foreach $code_sym_tab_key (keys %{$code_sym_tab}) {
	#	     $code_sym_tab_val = $code_sym_tab->{$code_sym_tab_key};
	#	     if (defined $code_sym_tab_val) {
	#		 printf "%s=%x ", $code_sym_tab_key, $code_sym_tab_val;
	#	     } else {
	#		 printf "%s=? ", $code_sym_tab_key;
	#	     }
	#	 }
	#	 print "\n";
	#    }
	#} else {
	#    #print "sym_tabs not defined!\n";
	#}

        ########################
        # set program counters #
        ########################
        if (defined $pc_global) {
            $code_entry->[6] = $pc_global;
        }
        if (defined $pc_local) {
            $code_entry->[7] = $pc_local;
        }

        ###################
        # set label_value #
        ###################
        $label_value = $pc_local;

        #####################
        # determine hexcode #
        #####################
        if (exists $self->{opcode_table}->{uc($code_opcode)}) {
            ################
            # valid opcode #
            ################
            $opcode_entries = $self->{opcode_table}->{uc($code_opcode)};
            $match   = 0;
            $error   = 0;
            $result  = 0;
            foreach $opcode_entry (@$opcode_entries) {
                if (!$match && !$error) {
                    $opcode_amode_expr   = $opcode_entry->[0];
                    $opcode_amode_check  = $opcode_entry->[1];
                    $opcode_amode_opcode = $opcode_entry->[2];
                    #check address mode
                    #printf STDERR "valid opcode: %s %s (%s)\n", $code_opcode, $code_args, $opcode_amode_opcode;
                    if ($code_args =~ $opcode_amode_expr) {
                        $error  = 0;
                        $result = 0;
                        #printf STDERR "valid arg format: %s \"%s\" (%s)\n", $code_opcode, $1, $opcode_amode_opcode;
                        if (&{$opcode_amode_check}($self,
                                                   [$1,$2,$3,$4,$5,$6,$7,$8],
                                                   $pc_global, $pc_local, $loc_cnt,
                                                   $code_sym_tabs,
                                                   \$opcode_entry->[2],
                                                   \$error,
                                                   \$result)) {
                            #printf STDERR "valid args: %s (%s)\n", $code_opcode, $opcode_amode_opcode;
                            $match = 1;
                            if ($error) {
                                #syntax error
                                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                                $error_count++;
                                #printf STDERR "ERROR: %s %s %s\n", $code_opcode, $opcode_amode_opcode, $opcode_amode_expr;
                            } elsif ($result) {
                                #opcode found
                                $code_entry->[8] = $result;
                                $code_entry->[9] = split " ", $result;
                                if (defined $pc_global) {
                                    #increment global PC
                                    $pc_global = $pc_global + $code_entry->[9];
                                }
                                if (defined $pc_local) {
                                    #increment local PC
                                    $pc_local = $pc_local + $code_entry->[9];
                                    if ($result =~ $cmp_no_hexcode) {
                                        $undef_count++;
                                        #print STDERR "$opcode_hexargs\n";
                                    }
                                } else {
                                    # undefined PC
                                    $undef_count++;
				    #printf STDERR "PC UNDEFINED\n";
                                }
                            } else {
                                #opcode undefined
                                #$pc_global = undef; #Better results if program counter keep an approximate value
                                #$pc_local = undef;
                                $undef_count++;
                                #printf STDERR "OPCODE UNDEFINED\n";
                            }
                        }
                    }#else {printf STDERR "MISMATCH: \"%s\" \"%s\"\n", $code_args, $opcode_amode_expr;}
                }
            }
            if (!$match) {
                if (!$error) {
                    $error = sprintf("invalid address mode for opcode \"%s\" (%s)", (uc($code_opcode),
                                                                                     $code_args));
                }
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $error_count++;
            }
        } elsif (exists $pseudo_opcodes->{uc($code_opcode)}) {
            #######################
            # valid pseudo opcode #
            #######################
            #print "valid pseudo opcode: $code_opcode ($code_entry->[0])\n";
            $pseudo_opcodes->{uc($code_opcode)}($self,
                                                \$pc_global,
                                                \$pc_local,
                                                \$loc_cnt,
                                                \$error_count,
                                                \$undef_count,
                                                \$label_value,
                                                $code_entry);
        } elsif (exists $self->{macros}->{uc($code_opcode)}) {
            #########
            # macro #
            #########
	    #set "MACRO" identifier
	    $code_entry->[8] = "MACRO";

	    #determine macro name
	    $macro_name = uc($code_opcode);

	    #check for recursive macro call
	    if (defined $code_macros) {
		$result = grep {$macro_name eq $_} @$code_macros;
		#printf "macros \"%s\", %b: %s\n", $macro_name, $result, join(", ", @$code_macros);
	    } else {
		$result = -1;
	    }

	    if ($result <= 0) {
		#check macro_args
		#@macro_args = split($del, $code_args);
	        @macro_args = ();
		while ($code_args =~ /^[,\s]*(\([^\(\)]*?\)|\".*?\"|\'.*?\'|[^\s,]+)/) {
		    #printf "macros args: \"%s\" (%d,%d) => %s\n", $code_args, $#macro_args, $self->{macro_argcs}->{$macro_name}, join(", ", @macro_args);
		    my $code_arg = $1; #set current $code_arg 
		    $code_args = $';#'  #remove current $code_arg from $code_args
		    #remove parenthesis from $current $code_arg		
		    if ($code_arg =~ /^\((.*)\)$/) {
			$code_arg = $1;
		    }
		    push @macro_args, $code_arg;
		}
		#printf "macros args: \"%s\" (%d,%d) => %s\n", $code_args, $#macro_args, $self->{macro_argcs}->{$macro_name}, join(", ", @macro_args);
		if (($#macro_args+1) == $self->{macro_argcs}->{$macro_name}) {
		    #determine macro hierarchy
		    if (defined $code_macros) {
			$macro_hierarchy = [$macro_name, @$code_macros];
		    } else {
			$macro_hierarchy = [$macro_name];
		    }
		    #printf "macros hierarchy: %s\n", join("/", @$macro_hierarchy);

		    #create a new local symbol table
		    $macro_sym_tab = {};
		    foreach $macro_symbol (keys %{$self->{macro_symbols}->{$macro_name}}) {
			$macro_sym_tab->{$macro_symbol} = undef;
			$undef_count++;
		    }
		    #printf "new macro table (%s): (%s) (%s)\n", $macro_name, join(",", keys %$macro_sym_tab), join(",", keys %{$self->{macro_symbols}->{$macro_name}});

		    if (defined $code_sym_tabs) {
			$macro_sym_tabs = [$macro_sym_tab, @$code_sym_tabs];
		    } else {
			$macro_sym_tabs = [$macro_sym_tab];
		    }
		    #printf "macro tables (%s): (%s)\n", join("/", @$macro_hierarchy), ($#$macro_sym_tabs+1);

		    #copy macro elements
		    #printf "macros: %d\n", ($#{$self->{macros}->{$macro_name}}+1);
		    $macro_entries = []; 
		    foreach $macro_entry (@{$self->{macros}->{$macro_name}}) {

			#replace macro comments
			@macro_comments = @{$macro_entry->[2]};
			$macro_comment  = pop @macro_comments;
			if ($macro_comment =~ /^(.*)(\;.*)$/ ) {
			    $macro_comment = $1;
			    $macro_comment_keep = $2;
			} else {
			    $macro_comment_keep = "";
			}
			foreach $macro_argc (1..$self->{macro_argcs}->{$macro_name}) {
			    $macro_comment_replace = $macro_args[$macro_argc-1];
			    $macro_comment =~ s/\\$macro_argc/$macro_comment_replace/g;
			    #printf "replace macro comment: %d \"%s\" => \"%s\"\n", $macro_argc, $macro_comment_replace, $macro_comment;
			}
			$macro_comment .=  $macro_comment_keep;
			
			#replace macro label
			$macro_label = $macro_entry->[3];
			foreach $macro_argc (1..$self->{macro_argcs}->{$macro_name}) {
			    $macro_label_replace = $macro_args[$macro_argc-1];
			    $macro_label =~ s/\\$macro_argc/$macro_label_replace/g;
			    #printf "replace macro label: %d \"%s\", \"%s\" => \"%s\"\n", $macro_argc, $macro_entry->[3], $macro_label_replace, $macro_label;
			}

			#replace macro opcodes
			$macro_opcode = $macro_entry->[4];
			foreach $macro_argc (1..$self->{macro_argcs}->{$macro_name}) {
			    $macro_opcode_replace = $macro_args[$macro_argc-1];
			    $macro_opcode =~ s/\\$macro_argc/$macro_opcode_replace/g;
			    #printf "replace macro opcode: %d \"%s\", \"%s\" => \"%s\"\n", $macro_argc, $macro_entry->[4], $macro_opcode_replace, $macro_opcode;
			}

			#replace macro args
			$macro_arg = $macro_entry->[5];
			foreach $macro_argc (1..$self->{macro_argcs}->{$macro_name}) {
			    $macro_arg_replace = $macro_args[$macro_argc-1];
			    $macro_arg =~ s/\\$macro_argc/$macro_arg_replace/g;
			    #$macro_arg =~ s/§$macro_argc/$macro_arg_replace/g;
			    #printf "replace macro arg: %d \"%s\", \"%s\" => \"%s\"\n", $macro_argc, $macro_entry->[5], $macro_arg_replace, $macro_arg;
			}

			#copy macro element
			push @$macro_entries , [$macro_entry->[0],
						$macro_entry->[1],
						[@macro_comments, $macro_comment],
						$macro_label,
						$macro_opcode,
						$macro_arg,
						$macro_entry->[6],
						$macro_entry->[7],
						$macro_entry->[8],
						$macro_entry->[9],
						$macro_entry->[10],
						$macro_hierarchy,
						$macro_sym_tabs];
			#printf "copy macro entries: \"%s\" \"%s\" (\"%s\")\n", $macro_entry->[4], $macro_arg, $macro_entry->[5];

		    }
		    
		    #insert macro into code
		    @macro_code_list = splice @{$self->{code}}, $code_entry_cnt+1;
		    push @{$self->{code}}, @$macro_entries;
		    push @{$self->{code}}, @macro_code_list;

		    #remove opcode and args from macro entry
		    $code_entry->[4] = "";
		    $code_entry->[5] = "";

		} else {
		    #wrong number of arguments
                    $error = sprintf("wrong number of arguments for macro \"%s\" (%s)", (uc($code_opcode),
                                                                                         $code_args));
		    $code_entry->[10] = [@{$code_entry->[10]}, $error];
		    $error_count++;
		}
	    } else {
		#nested macro call detected
		$error = sprintf("recursive call of  macro \"%s\"", (uc($code_opcode)));
		$code_entry->[10] = [@{$code_entry->[10]}, $error];
		$error_count++;
	    }
        } elsif ($code_opcode =~ /^\s*$/) {
            ###############
            # plain label #
            ###############
	    if (defined $code_entry->[8]) {
		if ($code_entry->[8] ne "MACRO") {
		    $code_entry->[8] = "";
		}
	    } else {
		$code_entry->[8] = "";
	    }
        } else {
            ##################
            # invalid opcode #
            ##################
            $error = sprintf("invalid opcode \"%s\"", $code_opcode);
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $error_count++;
            $pc_global = undef;
            $pc_local = undef;
            #print "$error\n";
        }

	######################
	# update label stack #
	######################
	if (defined $code_macros) {
	    $cur_macro_depth = $#$code_macros + 1;
	} else {
	    $cur_macro_depth = 0;
	}	    
	#printf "macro depth: %d (%d)\n", $cur_macro_depth, $prev_macro_depth;
	if ($prev_macro_depth < $cur_macro_depth) {
	    #nested macro started
	    unshift @label_stack, {};
	    #printf "macro started: (%d), %s\n", $cur_macro_depth, join(", ", @$code_macros);
	}
	if ($prev_macro_depth > $cur_macro_depth) {
	    #nested macro ended
	    shift @label_stack;
	    #if (defined  $code_macros) {
	    #	 printf "macro ended: (%d), %s\n", $cur_macro_depth, join(", ", @$code_macros);
	    #} else {
	    #	 printf "macro ended: (%d)\n", $cur_macro_depth;
	    #}
	}	    
	$prev_macro_depth = $cur_macro_depth;
	    
        #############
        # set label #
        #############
        if ($code_label =~ /\S/) {

            #use upper case symbol names
            $code_label = uc($code_label);
            #substitute LOC count
            if ($code_label =~ /^\s*(.+)\`\s*$/) {
                $code_label = uc(sprintf("%s%.4d", $1, $loc_cnt));
            }

            #################################
            # check for label redefinitions #
            #################################
            $label_ok = 1;
            if (exists $label_stack[0]->{$code_label}) {
                if (defined $label_stack[0]->{$code_label}) {
                    if (defined $label_value) {
                        if ($label_stack[0]->{$code_label} != $label_value) {
                            $error = sprintf("illegal redefinition of symbol \"%s\" (\$%X -> \$%X)", ($code_label,
                                                                                                      $label_stack[0]->{$code_label},
                                                                                                      $label_value));
                            $code_entry->[10] = [@{$code_entry->[10]}, $error];
                            $error_count++;
                            $label_ok = 0;
                        }
                    }
                }
            } else {
                $label_stack[0]->{$code_label} = $label_value;
            }

            if ($label_ok == 1) {
                ###############
                # check label #
                ###############
		if (defined $code_sym_tabs) {
		    $code_sym_tab_cnt = $#$code_sym_tabs;
		} else {
		    $code_sym_tab_cnt = -1;
		}
		if ($code_sym_tab_cnt < 0) {
		    #main code
		    if (exists $self->{comp_symbols}->{$code_label}) {
			if (defined $self->{comp_symbols}->{$code_label}) {
			    if (defined $label_value) {
				if ($self->{comp_symbols}->{$code_label} != $label_value) {
				    ######################
				    # label redefinition #
				    ######################
				    if ($self->{compile_count} >= ($max_comp_runs-5)) {
				            printf STDOUT "Hint! Symbol redefinition: %s %X->%X (%s %s)\n", ($code_label,
													     $self->{comp_symbols}->{$code_label},
													     $label_value,
													     ${$code_entry->[1]},
													     $code_entry->[0]);
				    }
				    $redef_count++;
				    $self->{comp_symbols}->{$code_label} = $label_value;
				}
			    } else {
				######################
				# label redefinition #
				######################
				if ($self->{compile_count} >= ($max_comp_runs-5)) {
				    printf STDOUT "Hint! Symbol redefinition: %s %X->undef (%s %s)\n", ($code_label,
													$self->{comp_symbols}->{$code_label},
													${$code_entry->[1]},
													$code_entry->[0]);
				}
				$redef_count++;
				$self->{comp_symbols}->{$code_label} = undef;
			    }
			} else {
			    ####################
			    # label definition #
			    ####################
			    $self->{comp_symbols}->{$code_label} = $label_value;
			}
		    } else {
			########################
			# new label definition #
			########################
			$self->{comp_symbols}->{$code_label} = $label_value;
			#printf STDERR "new: %s %s undef (%s %s)\n", ($code_label,
			#	 				      $self->{comp_symbols}->{$code_label},
			#	 				      ${$code_entry->[1]},
			#	 				      $code_entry->[0]);
		    }
		} else {
		    #macro label
		    if (exists $code_sym_tabs->[0]->{$code_label}) {
			if (defined $code_sym_tabs->[0]->{$code_label}) {
			    if (defined $label_value) {
				if ($code_sym_tabs->[0]->{$code_label} != $label_value) {
				    ######################
				    # label redefinition #
				    ######################
				    if ($self->{compile_count} >= ($max_comp_runs-5)) {
				            printf STDOUT "Hint! Symbol redefinition within a macro: %s %X->%X (%s %s)\n", ($code_label,
															    $code_sym_tabs->[0]->{$code_label},
															    $label_value,
															    ${$code_entry->[1]},
															    $code_entry->[0]);
				    }
				    $redef_count++;
				    $code_sym_tabs->[0]->{$code_label} = $label_value;
				}
			    } else {
				######################
				# label redefinition #
				######################
				if ($self->{compile_count} >= ($max_comp_runs-5)) {
				    printf STDOUT "Hint! Symbol redefinition within a macro: %s %X->undef (%s %s)\n", ($code_label,
														       $code_sym_tabs->[0]->{$code_label},
														       ${$code_entry->[1]},
														       $code_entry->[0]);
				}
				$redef_count++;
				$code_sym_tabs->[0]->{$code_label} = undef;
			    }
			} else {
			    ####################
			    # label definition #
			    ####################
			    $code_sym_tabs->[0]->{$code_label} = $label_value;
			}
		    } else {
			########################
			# new label definition #
			########################
			$code_sym_tabs->[0]->{$code_label} = $label_value;
		    }
		}
            }
        }
    }
    return [$error_count, $undef_count, $redef_count];
}

####################
# set_opcode_table #
####################
sub set_opcode_table {
    my $self    = shift @_;
    my $cpu     = shift @_;
    #print STDERR "CPU: $cpu\n";

    for ($cpu) {
        ######
        # N1 #
        ######
        /$cpu_n1/ && do {
            $self->{opcode_table} = $opctab_n1;
            return 0; last;};
        ###############
        # DEFAULT CPU #
        ###############
        $self->{opcode_table} = $opctab_n1;
        return sprintf "invalid CPU \"%s\". Using S12 opcode map instead.", $cpu;
    }
}

#######################
# evaluate_expression #
#######################
sub evaluate_expression {
    my $self     = shift @_;
    my $expr     = shift @_;
    my $pc_global   = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt  = shift @_;
    my $sym_tabs = shift @_;

    #terminal
    my $complement;
    my $string;
    #binery conversion
    my $binery_value;
    my $binery_char;
    #ascii conversion
    my $ascii_value;
    my $ascii_char;
    #symbol lookup
    my @symbol_tabs;
    my $symbol_tab;
    my $symbol_name;
    #formula
    my $formula;
    my $formula_left;
    my $formula_middle;
    my $formula_right;
    my $formula_resolved_left;
    my $formula_resolved_middle;
    my $formula_resolved_right;
    my $formula_error;
    #printf "evaluate_expression: \"%s\"\n", $expr;

    if (defined $expr) {
        #trim expression
        #$expr =~ s/^\s*//;
        #$expr =~ s/\s*$//;

        for ($expr) {
            #################
            # binary number #
            #################
            /$op_binery/ && do {
                $complement = $1;
                $string     = $2;
                #printf "terminal bin: \"%s\" \"%s\"\n", $complement, $string;
                $binery_value = 0;
                foreach $binery_char (split //, $string) {
                    if ($binery_char =~ /^[01]$/) {
                        $binery_value = $binery_value << 1;
                        if ($binery_char ne "0") {
                            $binery_value++;
                        }
                    }
                }
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~$binery_value)];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, ($binery_value * -1)];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, $binery_value];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            ##################
            # decimal number #
            ##################
            /$op_dec/ && do {
                $complement = $1;
                $string     = $2;
                $string =~ s/_//g;
                #printf "terminal dec: \"%s\" \"%s\"\n", $complement, $string;
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~(int(sprintf("%d", $string))))];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, (int(sprintf("%d", $string)) * (-1))];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, int(sprintf("%d", $string))];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            ######################
            # hexadecimal number #
            ######################
            /$op_hex/ && do {
                $complement = $1;
                $string     = $2;
                $string =~ s/_//g;
                #printf "terminal hex: \"%s\" \"%s\"\n", $complement, $string;
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~(hex($string)))];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, (hex($string) * (-1))];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, hex($string)];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            ###################
            # ASCII character #
            ###################
            /$op_ascii/ && do {
                $complement = $1;
                $string     = $2;
                #printf "terminal ascii: \"%s\" \"%s\"\n", $complement, $string;

                #replace escaped characters
                $string =~ s/\\,/,/g;   #escaped commas
                #$string =~ s/\\\ /\ /g; #escaped spaces
                #$string =~ s/\\\t/\t/g; #escaped tabss

                $ascii_value = 0;
                foreach $ascii_char (split //, $string) {
                    $ascii_value = $ascii_value << 8;
                    $ascii_value = $ascii_value | ord($ascii_char);
                }
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~$ascii_value)];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, ($ascii_value * (-1))];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, $ascii_value];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            #####################
            # current global PC #
            #####################
            /$op_curr_global_pc/ && do {
                $complement = $1;
                #printf "terminal addr: \"%s\" \"%s\"\n", $complement, $comp_pc_localed;
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~$pc_global)];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, ($pc_global * (-1))];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, $pc_global];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            ####################
            # current local PC #
            ####################
            /$op_curr_local_pc/ && do {
                $complement = $1;
                #printf "terminal addr: \"%s\" \"%s\"\n", $complement, $comp_pc_localed;
                for ($complement) {
                    /^~$/ && do {
                        #1's complement
                        return [0, (~$pc_local)];
                        last;};
                    /^\-$/ && do {
                        #2's complement
                        return [0, ($pc_local * (-1))];
                        last;};
                    /^\s*$/ && do {
                        #no complement
                        return [0, $pc_local];
                        last;};
                    #syntax error
                    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
                }
                last;};
            ###################
            # compiler symbol #
            ###################
            /$op_symbol/ && do {
                $complement = $1;
                $string     = uc($2);
                ########################
                # substitute loc count #
                ########################
                #substitute LOC count
                if ($string =~ /^\s*(.+)\`\s*$/) {
                #if ($string =~ /^\s*(.*)\`\s*$/) {
                    $string = sprintf("%s%.4d", $1, $loc_cnt);
                }
                #printf STDERR "terminal symb: \"%s\" \"%s\"\n", $complement, $string;
                if ($string !~ $op_keywords) {
		    if (defined $sym_tabs) {
			@symbol_tabs = (@$sym_tabs, $self->{comp_symbols});
			#printf STDERR "symbol_tabs: %d\n", ($#symbol_tabs+1);
		    } else {
			@symbol_tabs = ($self->{comp_symbols});
			#printf STDERR "symbol_tabs: %d (no sym_tabs)\n", ($#symbol_tabs+1);
		    }
		    
		    foreach $symbol_tab (@symbol_tabs) {
			#printf STDERR "\"%s\" -> \"%s\": %s\n", $expr, $string, join(",", keys %$symbol_tab);
			if (exists $symbol_tab->{uc($string)}) {
			    if (defined $symbol_tab->{uc($string)}) {
				#printf STDERR "symbol: \"%s\" \"%s\"\n", uc($string), $symbol_tab->{uc($string)};

				for ($complement) {
				    /^~$/ && do {
					#1's complement
					return [0, (~$symbol_tab->{uc($string)})];
					last;};
				    /^\-$/ && do {
					#2's complement
					return [0, ($symbol_tab->{uc($string)} * (-1))];
					last;};
				    /^\s*$/ && do {
					#no complement
					return [0, $symbol_tab->{uc($string)}];
					last;};
				    #syntax error
				    return [sprintf("wrong syntax \"%s%s\"", $complement, $string), undef];
				}
			    } else {
				#printf STDERR "symbol: \"%s\" undefined\n", uc($string);
				return [0, undef];
			    }
			}
		    }

                    if (! exists $self->{compile_count}) {
                        return [sprintf("unknown symbol \"%s\"", $string), undef];
                    } elsif ($self->{compile_count} > 1) {
                        return [sprintf("unknown symbol \"%s\"", $string), undef];
                    } else {
                        return [0, undef];
                    }
                } else {
                    return [sprintf("invalid use of keyword \"%s\"", $string), undef];
                }
                last;};
            ###############
            # parenthesis #
            ###############
            /$op_formula_pars/ && do {
                $formula_left   = $1;
                $formula_middle = $2;
                $formula_right  = $3;
                ($formula_error, $formula_resolved_middle) = @{$self->evaluate_expression($formula_middle, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_middle) {
                    return [0, undef];
                } else {
                    $formula = sprintf("%s%d%s", ($formula_left,
                                                  $formula_resolved_middle,
                                                  $formula_right));

                    return $self->evaluate_expression($formula, $pc_global, $pc_local, $loc_cnt, $sym_tabs);
                }
                last;};
            #############################
            # double negation/invertion #
            #############################
            /$op_formula_complement/ && do {
                $complement     = $1;
                $formula_right  = $2;
                ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_right) {
                    return [0, undef];
                } else {
                    for ($complement) {
                        /^~$/ && do {
                            #1's complement
                            return [0, (~$formula_resolved_right)];
                            last;};
                        /^\-$/ && do {
                            #2's complement
                            return [0, ($formula_resolved_right * (-1))];
                            last;};
                        #syntax error
                        return [sprintf("wrong syntax \"%s%s\"", $complement, $formula_right), undef];
                    }
                }
                last;};
            #######
            # and #
            #######
            /$op_formula_and/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve ANDs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left & $formula_resolved_right)];
                    }
                }
                last;};
            ######
            # or #
            ######
            /$op_formula_or/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve ORs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left | $formula_resolved_right)];
                    }
                }
                last;};
            ########
            # exor #
            ########
            /$op_formula_exor/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve EXORs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left ^ $formula_resolved_right)];
                    }
                }
                last;};
            ##############
            # rightshift #
            ##############
            /$op_formula_rightshift/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve RIGHTSHIFTSs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left >> $formula_resolved_right)];
                    }
                }
                last;};
            #############
            # leftshift #
            #############
            /$op_formula_leftshift/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve LEFTSHIFTs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left << $formula_resolved_right)];
                    }
                }
                last;};
            ##################
            # multiplication #
            ##################
            /$op_formula_mul/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve MULs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left * $formula_resolved_right)];
                    }
                }
                last;};
            ############
            # division #
            ############
            /$op_formula_div/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve DIVs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, int($formula_resolved_left / $formula_resolved_right)];
                    }
                }
                last;};
            ###########
            # modulus #
            ###########
            /$op_formula_mod/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve MODs: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left % $formula_resolved_right)];
                    }
                }
                last;};
            ########
            # plus #
            ########
            /$op_formula_plus/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve PLUSes: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left + $formula_resolved_right)];
                    }
                }
                last;};
            #########
            # minus #
            #########
            /$op_formula_minus/ && do {
                $formula_left   = $1;
                $formula_right  = $2;
                #printf "resolve MINUSes: \"%s\" \"%s\"\n", $formula_left, $formula_right;

                #evaluate left formula
                ($formula_error, $formula_resolved_left) = @{$self->evaluate_expression($formula_left, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                if ($formula_error) {
                    return [$formula_error, undef];
                } elsif (! defined $formula_resolved_left) {
                    return [0, undef];
                } else {
                    #evaluate right formula
                    ($formula_error, $formula_resolved_right) = @{$self->evaluate_expression($formula_right, $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
                    if ($formula_error) {
                        return [$formula_error, undef];
                    } elsif (! defined $formula_resolved_right) {
                        return [0, undef];
                    } else {
                        return [0, ($formula_resolved_left - $formula_resolved_right)];
                    }
                }
                last;};
            ##############
            # whitespace #
            ##############
            /$op_whitespace/ && do {
                return [0, undef];
                last;};
            ##################
            # unknown syntax #
            ##################
            return [sprintf("wrong syntax \"%s\"", $expr), undef];
            #return [sprintf("wrong syntax", $expr), undef];
            }
    } else {
        return [0, undef];
    }
    return [0, undef];
}

########################
# determine_addrspaces #
########################
sub determine_addrspaces {
    my $self      = shift @_;

    #code
    my $code_pc_global;
    my $code_pc_local;
    my $code_hex;
    #data
    my $address;
    my $word;
    my $first_word;

    ########################
    # reset address spaces #
    ########################
    $self->{global_addrspace} = {};
    $self->{local_addrspace} = {};

    #############
    # code loop #
    #############
    #print "compile_run:\n";
    foreach $code_entry (@{$self->{code}}) {
        $code_pc_global   = $code_entry->[6];
        $code_pc_local    = $code_entry->[7];
        $code_hex         = $code_entry->[8];

        ########################
        # global address space #
        ########################
        if (defined $code_pc_global) {
            $address = $code_pc_global;
            if (($code_hex !~ /$cmp_no_hexcode/) &&
                ($code_hex !~ /^\s*$/)) {
		$first_word = 1;
                foreach $word (split /\s+/, $code_hex) {
                    $self->{global_addrspace}->{$address} = [hex($word),
                                                            $code_entry,
						  	    $first_word];
		    $first_word = 0;
                    $address++;
                }
            }
        }

        #######################
        # local address space #
        #######################
        if (defined $code_pc_local) {
            $address = $code_pc_local;
            if (($code_hex !~ /$cmp_no_hexcode/) &&
                ($code_hex !~ /^\s*$/)) {
		$first_word = 1;
                foreach $word (split /\s+/, $code_hex) {
                    $self->{local_addrspace}->{$address} = [hex($word),
                                                          $code_entry,
							  $first_word];
		    $first_word = 0;
                    $address++;
                }
            }
        }
    }
}

###########
# outputs #
###########
#################
# print_listing #
#################
sub print_listing {
    my $self      = shift @_;

    #code
    my $code_entry;
    my $code_file;
    my $code_line;
    my $code_comments;
    my $code_pc_global;
    my $code_pc_local;
    my $code_hex;
    my $code_errors;
    my $code_error;
    my $code_macros;
    my $code_pc_global_string;
    my $code_pc_local_string;
    my @code_hex_words;
    my @code_hex_strings;
    my $code_hex_string;
    #comments
    my @cmt_lines;
    my $cmt_line;
    my $cmt_last_line;
    #output
    my $out_string;

    ############################
    # initialize output string #
    ############################
    $out_string = "";

    #############
    # code loop #
    #############
    foreach $code_entry (@{$self->{code}}) {

        $code_line     = $code_entry->[0];
        $code_file     = $code_entry->[1];
        $code_comments = $code_entry->[2];
        $code_pc_global   = $code_entry->[6];
        $code_pc_local   = $code_entry->[7];
        $code_hex      = $code_entry->[8];
        $code_errors   = $code_entry->[10];
        $code_macros   = $code_entry->[11];

        #convert integers to strings
        if (defined $code_pc_global) {
            $code_pc_global_string = sprintf("%.6X", $code_pc_global);
        } else {
            #$code_pc_global_string = "??????";
            $code_pc_global_string = "      ";

        }
        if (defined $code_pc_local) {
            $code_pc_local_string = sprintf("%.6X", $code_pc_local);
        } else {
            $code_pc_local_string = "??????";
        }

        if (defined $code_hex) {
            for ($code_hex) {
                ##################################
                # whitespaces instead of hexcode #
                ##################################
                /^\s*$/ && do {
                    @code_hex_strings = ("");
                    last;};
                #############################
                # string instead of hexcode #
                #############################
                /$cmp_no_hexcode/ && do {
                    @code_hex_strings = ($1);
                    last;};
                ###########
                # hexcode #
                ###########
                @code_hex_strings = ();
                @code_hex_words = split /\s+/, $code_hex;
                while ($#code_hex_words >= 0) {
                    $code_hex_string = "";
                    if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
                                                                                     (shift @code_hex_words)));}
                    if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
                                                                                     (shift @code_hex_words)));}
                    if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
                                                                                     (shift @code_hex_words)));}
                    if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
                                                                                     (shift @code_hex_words)));}
		    
		    if (($#code_hex_words >= 0) && (length($code_hex_words[0]) < 4)) {

			if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
											 (shift @code_hex_words)));}
			if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
											 (shift @code_hex_words)));}
			if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
											 (shift @code_hex_words)));}
			if ($#code_hex_words >= 0) {$code_hex_string = sprintf("%s %s", ($code_hex_string,
											 (shift @code_hex_words)));}
		    }
                    #trim string
                    $code_hex_string =~ s/^\s*//;
                    $code_hex_string =~ s/\s*$//;
                    push @code_hex_strings, $code_hex_string;
                }
            }
	    #printf "\"%s\" \"%s\" (%s)\n", $code_hex, $code_hex_strings[0], $code_comments->[0]
        } else {
            @code_hex_strings = ("??");
        }

        ##################
        # print comments #
        ##################
        @cmt_lines = @$code_comments;
        $cmt_last_line = pop @cmt_lines;
        foreach $cmt_line (@cmt_lines) {
	    if (defined $code_macros) {
		if ($#$code_macros < 0) {
		    $out_string .= sprintf("%-6s %-6s %-23s %ls\n", "", "", "", $cmt_line);
		} else {
		    $out_string .= sprintf("%-6s %-6s %-23s %-80s (%ls)\n", "", "", "", $cmt_line, join("/", reverse @$code_macros));
		}
	    } else {
		$out_string .= sprintf("%-6s %-6s %-23s %ls\n", "", "", "", $cmt_line);
	    }
        }

        ###################
        # print code line #
        ###################
	if (defined $code_macros ) {
	    if ($#$code_macros < 0) {
		$out_string .= sprintf("%-6s %-6s %-23s %ls\n", ($code_pc_local_string,
								 $code_pc_global_string,
								 shift @code_hex_strings,
								 $cmt_last_line));
	    } else {
	        #printf STDERR "\"%s\" \"%s\" (%s)\n", $code_hex, $code_hex_strings[0], $code_comments->[0];
	        #printf STDERR "\"%-80.25s\"->%d \n", $cmt_last_line, length($cmt_last_line);
                #printf STDERR " 0        1         2         3         4         5         6         7         8         9\n";
                #printf STDERR " 123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890\n";		
		#printf STDERR "%-6s %-6s %-23s \"%s\" (%ls)\n", ($code_pc_local_string,
		#						 $code_pc_global_string,
		#	  					 $code_hex_strings[0],
		#						 $cmt_last_line,
		#						 join("/", reverse @$code_macros));
		$out_string .= sprintf("%-6s %-6s %-23s %-80s (%ls)\n", ($code_pc_local_string,
									 $code_pc_global_string,
									 shift @code_hex_strings,
									 $cmt_last_line,
				                                         join("/", reverse @$code_macros)));
	    }
	} else {
	    $out_string .= sprintf("%-6s %-6s %-23s %ls\n", ($code_pc_local_string,
							     $code_pc_global_string,
							     shift @code_hex_strings,
							     $cmt_last_line));
	} 

        ##############################
        # print additional hex words #
        ##############################
        foreach $code_hex_string (@code_hex_strings) {
            $out_string .= sprintf("%-6s %-6s %-23s %ls\n", "", "", $code_hex_string, "");
        }

        ################
        # print errors #
        ################
        foreach $code_error (@$code_errors) {
            $out_string .= sprintf("%-6s %-6s %-23s ERROR! %s (%s, line: %d)\n", ("", "", "",
                                                                                  $code_error,
                                                                                  $$code_file,
                                                                                  $code_line));
        }
    }
    return $out_string;
}

#######################
# print_global_binary #
#######################
sub print_global_binary {
    my $self              = shift @_;
    my $start_addr        = shift @_;
    my $end_addr          = shift @_;

    #memoryspace
    my $mem_addr;
    my $mem_entry;
    my $mem_word;
    #output
    my @out_list;

    ##########################
    # initialize output list #
    ##########################
    @out_list = ();

    ################
    # address loop #
    ################
    for ($mem_addr =  $start_addr; 
	 $mem_addr <= $end_addr;
	 $mem_addr++) {

	if (exists $self->{global_addrspace}->{$mem_addr}) {
	    $mem_entry = $self->{global_addrspace}->{$mem_addr};
	    $mem_word  = hex($mem_entry->[0]);
	} else {
	    $mem_word  = 0;
	}

	push  @out_list, $mem_word;
	
	return pack "C*", @out_list;   
    }
}

####################
# print_local_binary #
####################
sub print_local_binary {
    my $self              = shift @_;
    my $start_addr        = shift @_;
    my $end_addr          = shift @_;

    #memoryspace
    my $mem_addr;
    my $mem_entry;
    my $mem_word;
    #output
    my @out_list;

    ##########################
    # initialize output list #
    ##########################
    @out_list = ();

    ################
    # address loop #
    ################
    for ($mem_addr =  $start_addr; 
	 $mem_addr <= $end_addr;
	 $mem_addr++) {

	if (exists $self->{local_addrspace}->{$mem_addr}) {
	    $mem_entry = $self->{local_addrspace}->{$mem_addr};
	    $mem_word  = hex($mem_entry->[0]);
	} else {
	    $mem_word  = 0;
	}

	push  @out_list, $mem_word;
	
	return pack "C*", @out_list;   
    }
}

##################
# print_mem_file #
##################
sub print_mem_file {
    my $self              = shift @_;
    #memoryspace
    my $mem_addr;
    my $mem_exp_addr;
    my $mem_entry;
    my $mem_word;
    #comments
    my @comment;
    my $comment_line;
    my $last_comment_line;
    #output
    my $out_string;

    ########################
    # initialize variables #
    ########################
    $out_string    = "";
    $mem_exp_addr  = 0;
 
    foreach $mem_addr (sort {$a <=> $b} keys %{$self->{global_addrspace}}) {
        $mem_entry   = $self->{global_addrspace}->{$mem_addr};
        $mem_word    = $mem_entry->[0];
        $first_word  = $mem_entry->[2];
	
        if (($mem_exp_addr != $mem_addr) || ($out_string eq "")) {
            if ($out_string ne "") {
                $out_string .= "\n";
            }
            $out_string .= sprintf("@%.4X\n", $mem_addr);
        }

        @comment = @{$mem_entry->[1]->[2]};
        if (($#comment >= 0) && $first_word) {
            $last_comment_line = pop @comment;
            foreach $comment_line (@comment) {
                $out_string .= sprintf("       //%.4X: %s\n", $mem_addr, $comment_line);
            }
            $out_string .= sprintf("%.4X   //%.4X: %s\n", $mem_word, $mem_addr, $last_comment_line);
        } else {
            $out_string .= sprintf("%.4X   //%.4X\n", $mem_word, $mem_addr);
        }
        $mem_exp_addr = $mem_addr + 1;
    }

    return $out_string;
}

#######################
# print_error_summary #
#######################
sub print_error_summary {
    my $self      = shift @_;

    #code
    my $code_entry;
    my $code_file;
    my $code_line;
    my $code_comments;
    my $code_pc_global;
    my $code_pc_local;
    my $code_hex;
    my $code_errors;
    my $code_error;
    my $code_macros;
    #comments
    my @cmt_lines;
    my $cmt_last_line;
   #output
   my $out_string;
   my $out_count;

    ############################
    # initialize output string #
    ############################
    $out_string = "";
    $out_count  = 0;

    #############
    # code loop #
    #############
    foreach $code_entry (@{$self->{code}}) {

        $code_line     = $code_entry->[0];
        $code_file     = $code_entry->[1];
        $code_comments = $code_entry->[2];
        $code_pc_global   = $code_entry->[6];
        $code_pc_local   = $code_entry->[7];
        $code_hex      = $code_entry->[8];
        $code_errors   = $code_entry->[10];
        $code_macros   = $code_entry->[11];

        ################
        # print errors #
        ################
        foreach $code_error (@$code_errors) {
	    $out_count++;
	    if ($out_count <= 5) {
		#extract source code
		#@cmt_lines = @$code_comments;
		#$cmt_last_line = pop @cmt_lines;
		#print error message
		#$out_string .= sprintf("ERROR! %s (%s, line: %d) -> %s\n", ($code_error,
		#						            $$code_file,
		#						            $code_line,
                #                                                            $cmt_last_line));
		$out_string .= sprintf("ERROR! %s (%s, line: %d)\n", ($code_error,
								      $$code_file,
								      $code_line));
	    } elsif ($out_count == 6) {
		$out_string .= "...\n";
	    } else {
		last;
	    }
        }
    }
    return $out_string;
}

###################
# print_mem_alloc #
###################
sub print_mem_alloc {
    my $self              = shift @_;

    #code entries
    my $code_entry;
    my $code_pc_global;
    my $code_pc_local;
    my $code_hex;
    my $code_words;
    #allocation tracking
    my $offset;
    my %var_alloc  = ();
    my %code_alloc = ();
    #address parser
    my $cur_local_addr;
    my $cur_global_addr;
    my $last_local_addr;
    my $last_global_addr;
    #address segments
    my $local_seg_start;
    my $local_seg_end;
    my $global_seg_start;
    my $global_seg_end;	
    #output
    my $out_string;
    #flag
    my $first_segment;

    #############
    # code loop #
    #############
    foreach $code_entry (@{$self->{code}}) {
        $code_pc_global   = $code_entry->[6];
        $code_pc_local   = $code_entry->[7];
        $code_hex      = $code_entry->[8];
        $code_words    = $code_entry->[9];
	if (defined $code_words) {
	    if ($code_hex !~ /^\s*$/) {
		#code
		foreach $offset (0..($code_words-1)) {
		    if (defined $code_pc_global) {
			$code_alloc{$code_pc_local+$offset}=$code_pc_global+$offset;
		    } else {
			$code_alloc{$code_pc_local+$offset}=undef;
		    }
		    #printf STDERR "code: %X %X\n", $code_pc_local+$offset, $code_alloc{$code_pc_local+$offset};
		}
	    } else {
		#variables	
		#printf STDERR "VAR! %X\n", $code_pc_local;
		foreach $offset (0..($code_words-1)) {
		    if (defined $code_pc_global) {
			$var_alloc{$code_pc_local+$offset}=$code_pc_global+$offset;
		    } else {
			$var_alloc{$code_pc_local+$offset}=undef;
		    }
		    #printf STDERR "var: %X %X %X\n", $code_pc_local, $code_pc_global, $offset;
		}
	    }
	}
    }
   #printf STDERR "var hash: %s\n", join(",", keys{%var_alloc});
 
    #############################
    # variable allocation table #
    #############################
    $out_string  = "Variable Allocation:\n";
    $out_string .= "Local             Global\n";
    $out_string .= "---------------   ---------------\n";
    $first_segment = 1;
    foreach $cur_local_addr (sort {$a <=> $b} keys %var_alloc) {
	$cur_global_addr = $var_alloc{$cur_local_addr};
	#printf STDERR "VAR: %X %X\n", $cur_local_addr, $cur_global_addr;
	if ($first_segment) {
	    $first_segment = 0;
	    $local_seg_start = $cur_local_addr;
	    $global_seg_start = $cur_global_addr;
	} elsif ((($last_local_addr+1) != $cur_local_addr)   ||
		 ((defined  $cur_global_addr)  &&
		  (defined  $last_global_addr) &&
		  (($last_global_addr+1) != $cur_global_addr)) ||
		 ( (defined  $cur_global_addr) && !(defined  $last_global_addr)) ||
		 (!(defined  $cur_global_addr) &&  (defined  $last_global_addr))) {
	#} elsif (($last_local_addr+1) != $cur_local_addr) {
	    #printf STDERR "NEW: %X %X %X %X\n", $cur_local_addr, $cur_global_addr, $last_local_addr, $last_global_addr;
	    $local_seg_end = $last_local_addr;
	    $global_seg_end = $last_global_addr;
	    #print segment boundaries
	    if ((defined $global_seg_start) && (defined $global_seg_end)) {
		$out_string .= sprintf("%.6X - %.6X   %.6X - %.6X\n", $local_seg_start,
				                                      $local_seg_end,
			             	                              $global_seg_start,
				                                      $global_seg_end);
	    } else {
		$out_string .= sprintf("%.6X - %.6X\n", $local_seg_start,
				                        $local_seg_end);
	    }
	    #start new segment
	    $local_seg_start = $cur_local_addr;
	    $global_seg_start = $cur_global_addr;	    
	}
	$last_local_addr = $cur_local_addr;
	$last_global_addr = $cur_global_addr;
    }
    $local_seg_end = $last_local_addr;
    $global_seg_end = $last_global_addr;
    #print segment boundaries
    if ((defined $global_seg_start) && (defined $global_seg_end)) {
	$out_string .= sprintf("%.6X - %.6X   %.6X - %.6X\n", $local_seg_start,
			                                      $local_seg_end,
			                                      $global_seg_start,
			                                      $global_seg_end);
    } else {
	$out_string .= sprintf("%.6X - %.6X\n", $local_seg_start,
			                        $local_seg_end);
    }
    #print STDERR $out_string;
    #exit;
    #########################
    # code allocation table #
    #########################
    $out_string .= "\n";
    $out_string .= "Code Allocation:\n";
    $out_string .= "Local             Global\n";
    $out_string .= "---------------   ---------------\n";
    $first_segment = 1;
    foreach $cur_local_addr (sort {$a <=> $b} keys %code_alloc) {
	$cur_global_addr = $code_alloc{$cur_local_addr};
	#printf STDERR "CODE: %X %X\n", $cur_local_addr, $cur_global_addr;
	if ($first_segment) {
	    $first_segment = 0;
	    $local_seg_start = $cur_local_addr;
	    $global_seg_start = $cur_global_addr;
	} elsif ((($last_local_addr+1) != $cur_local_addr)   ||
		 ((defined  $cur_global_addr)  &&
		  (defined  $last_global_addr) &&
		  (($last_global_addr+1) != $cur_global_addr)) ||
		 ( (defined  $cur_global_addr) && !(defined  $last_global_addr)) ||
		 (!(defined  $cur_global_addr) &&  (defined  $last_global_addr))) {
	#} elsif (($last_local_addr+1) != $cur_local_addr) {
	    $local_seg_end = $last_local_addr;
	    $global_seg_end = $last_global_addr;
	    #print segment boundaries
	    if ((defined $global_seg_start) && (defined $global_seg_end)) {
		$out_string .= sprintf("%.6X - %.6X   %.6X - %.6X\n", $local_seg_start,
				                                      $local_seg_end,
			             	                              $global_seg_start,
				                                      $global_seg_end);
	    } else {
		$out_string .= sprintf("%.6X - %.6X\n", $local_seg_start,
				                        $local_seg_end);
	    }
	    #start new segment
	    $local_seg_start = $cur_local_addr;
	    $global_seg_start = $cur_global_addr;	    
	}
	$last_local_addr = $cur_local_addr;
	$last_global_addr = $cur_global_addr;
    }
    $local_seg_end = $last_local_addr;
    $global_seg_end = $last_global_addr;
    #print segment boundaries
    if ((defined $global_seg_start) && (defined $global_seg_end)) {
	$out_string .= sprintf("%.6X - %.6X   %.6X - %.6X\n", $local_seg_start,
			                                      $local_seg_end,
			                                      $global_seg_start,
			                                      $global_seg_end);
    } else {
	$out_string .= sprintf("%.6X - %.6X\n", $local_seg_start,
			                        $local_seg_end);
    }
    return $out_string;
}

#########################
# pseudo opcode handler #
#########################
##############
# psop_align #
##############
sub psop_align {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $bit_mask;
    my $bit_mask_res;
    my $fill_word;
    my $fill_word_res;
    #hex code
    my @hex_code;
    #temporary
    my $error;
    my $value;
    my $count;
    
    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];
    $code_args =~ s/^\s*//;
    $code_args =~ s/\s*$//;
    for ($code_args) {
        ############
        # bit mask #
        ############
        /$psop_1_arg/ && do {
            $bit_mask        = $1;
            #printf STDERR "ALLIGN: \"%X\"\n", $bit_mask;

            ######################
            # determine bit mask #
            ######################
            ($error, $bit_mask_res) = @{$self->evaluate_expression($bit_mask,
                                                                   $$pc_global_ref,
                                                                   $$pc_local_ref,
                                                                   $$loc_cnt_ref,
								   $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                $$pc_global_ref      = undef;
                $$pc_local_ref      = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } elsif (! defined $bit_mask_res) {
                ###################
                # undefined value #
                ###################
                $$pc_global_ref      = undef;
                $$pc_local_ref      = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } elsif (! defined $$pc_local_ref) {
                ######################
                # undefined local PC #
                ######################
                $$pc_global_ref      = undef;
                $$pc_local_ref      = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } else {
                ##################
                # valid bit mask #
                ##################
		$count = 0;	
                while ($$pc_local_ref & $bit_mask_res) {
                    if (defined $$pc_global_ref) {$$pc_global_ref++;}
                    if (defined $$pc_local_ref) {$$pc_local_ref++;}
		    $count++;
                }
                #$code_entry->[6]  = $$pc_global_ref;
                #$code_entry->[7]  = $$pc_local_ref;
                $code_entry->[8]  = "";
                $code_entry->[9]  = $count;
                #$$label_value_ref = $$pc_local_ref;
            }
            last;};
        #######################
        # bit mask, fill word #
        #######################
        /$psop_2_args/ && do {
            $bit_mask  = $1;
            $fill_word = $2;
            ######################
            # determine bit mask #
            ######################
            ($error, $bit_mask_res) = @{$self->evaluate_expression($bit_mask,
                                                                   $$pc_global_ref,
                                                                   $$pc_local_ref,
                                                                   $$loc_cnt_ref,
								   $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                $$pc_global_ref      = undef;
                $$pc_local_ref      = undef;
                $$label_value_ref = undef;
            } elsif (! defined $bit_mask_res) {
                ###################
                # undefined value #
                ###################
                $$pc_global_ref      = undef;
                $$pc_local_ref      = undef;
                $$label_value_ref = undef;
                $$undef_count++;
            } else {
                ##################
                # valid bit mask #
                ##################
                #######################
                # determine fill word #
                #######################
                ($error, $fill_word_res) = @{$self->evaluate_expression($fill_word,
                                                                        $$pc_global_ref,
                                                                        $$pc_local_ref,
                                                                        $$loc_cnt_ref,
								        $code_entry->[12])};
                if ($error) {
                    ################
                    # syntax error #
                    ################
                    $code_entry->[10] = [@{$code_entry->[10]}, $error];
                    $$error_count_ref++;
                    return;
                } elsif (! defined $fill_word_res) {
                    ###################
                    # undefined value #
                    ###################
                    while ($$pc_local_ref & $bit_mask_res) {
                        if (defined $$pc_global_ref) {$$pc_global_ref++;}
                        if (defined $$pc_local_ref) {$$pc_local_ref++;}
                    }
                    #$$label_value_ref = $$pc_local_ref;
                    #undefine hexcode
                    $code_entry->[8] = undef;
                    $$undef_count++;
                } else {
                    ###################
                    # valid fill word #
                    ###################
                    @hex_code = ();
                    while ($$pc_local_ref & $bit_mask_res) {
                        if (defined $$pc_global_ref) {$$pc_global_ref++;}
                        if (defined $$pc_local_ref) {$$pc_local_ref++;}
                        push @hex_code, sprintf("%.4X", ($fill_word_res & 0xffff));
                    }
                    #set hex code and word count
                    $code_entry->[8]  = join " ", @hex_code;
                    $code_entry->[9]  = ($#hex_code + 1);
                }
            }
            last;};
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode ALIGN (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
        $$pc_global_ref     = undef;
        $$pc_local_ref     = undef;
        $code_entry->[8] = undef;
    }
}

############
# psop_cpu #
############
sub psop_cpu {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_label = $code_entry->[1];
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_1_arg/) {
        ################
        # one argument #
        ################
        $value = $1;
        #print STDERR "CPU: $value\n";
        $error = $self->set_opcode_table($value);
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
        } else {
            ##################
            # valid argument #
            ##################
            #check if symbol already exists
            $code_entry->[8]  = sprintf("%s CODE:", $value);
        }
    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode CPU (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}


###########
# psop_dw #
###########
sub psop_dw {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;


    #arguments
    my $code_args;
    my $code_arg;
    my @code_args_res;
    my $code_args_defined;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];

    #####################
    # resolve arguments #
    #####################
    @code_args_res     = ();
    $code_args_defined = 1;
    foreach $code_arg (split $del, $code_args) {
        ($error, $value) = @{$self->evaluate_expression($code_arg,
                                                        $$pc_global_ref,
                                                        $$pc_local_ref,
                                                        $$loc_cnt_ref,
						        $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
            if (defined $$pc_global_ref) {$$pc_global_ref += 1;}
            if (defined $$pc_local_ref) {$$pc_local_ref += 1;}
            push @code_args_res, 0;
            $code_args_defined = 0;
        } elsif (! defined $value) {
            ###################
            # undefined value #
            ###################
            if (defined $$pc_global_ref) {$$pc_global_ref += 1;}
            if (defined $$pc_local_ref) {$$pc_local_ref += 1;}
            push @code_args_res, 0;
            $code_args_defined = 0;
        } else {
            ##################
            # valid argument #
            ##################
            if (defined $$pc_global_ref) {$$pc_global_ref += 1;}
            if (defined $$pc_local_ref) {$$pc_local_ref += 1;}
            push @code_args_res, sprintf("%.4X", ($value & 0xffff));
        }
    }

    #set hex code and word count
    if ($code_args_defined) {
        $code_entry->[8] = join " ", @code_args_res;
    } else {
        $$undef_count_ref++;
    }
    $code_entry->[9] = ($#code_args_res + 1);
}

############
# psop_dsw #
############
sub psop_dsw {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref   = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_1_arg/) {
        ################
        # one argument #
        ################
        ($error, $value) = @{$self->evaluate_expression($1,
                                                        $$pc_global_ref,
                                                        $$pc_local_ref,
                                                        $$loc_cnt_ref,
						        $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
            $$pc_global_ref = undef;
            $$pc_local_ref = undef;
        } elsif (! defined $value) {
            ###################
            # undefined value #
            ###################
            $$pc_global_ref = undef;
            $$pc_local_ref = undef;
        } else {
            ##################
            # valid argument #
            ##################
            if (defined $$pc_global_ref) {$$pc_global_ref = $$pc_global_ref + $value;}
            if (defined $$pc_local_ref) {$$pc_local_ref = $$pc_local_ref + $value;}
            $code_entry->[8] = "";
            $code_entry->[9] = $value;
        }
    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode DS.W (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
        $$pc_global_ref = undef;
        $$pc_local_ref = undef;
    }
}

##############
# psop_error #
##############
sub psop_error {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $string;
    my $first_char;
    #hex code
    my $char;
    my @hex_code;
    #temporary

    ##################
    # read arguments #
    ##################
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_string/) {
        $string = $1;

        #trim string
        $string =~ s/^\s*//;
        $string =~ s/\s*$//;

        #trim first character
        $string     =~ s/^(.)//;
        $first_char = $1;

        #trim send of string
        if ($string =~ /^(.*)$first_char/) {$string = $1;}
        #printf STDERR "fcc: \"%s\" \"%s\"\n", $first_char, $string;

        $error = $string;
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
	
    } else {
        ################
        # syntax error #
        ################
        $error = "intentional compile error";
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

############
# psop_equ #
############
sub psop_equ {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_label;
    my $code_args;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_label = $code_entry->[1];
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_1_arg/) {
        ################
        # one argument #
        ################
        ($error, $value) = @{$self->evaluate_expression($1,
                                                        $$pc_global_ref,
                                                        $$pc_local_ref,
                                                        $$loc_cnt_ref,
						        $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
        } elsif (! defined $value) {
            ###################
            # undefined value #
            ###################
            $$label_value_ref = undef;
            $code_entry->[8]  = sprintf("-> ????", $value);
        } else {
            ##################
            # valid argument #
            ##################
            #check if symbol already exists
            $$label_value_ref = $value;
            $code_entry->[8]  = sprintf("-> \$%.4X", $value);
        }
    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode EQU (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

############
# psop_fcc #
############
sub psop_fcc {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $string;
    my $first_char;
    #hex code
    my $char;
    my @hex_code;
    #temporary

    ##################
    # read arguments #
    ##################
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_string/) {
        $string = $1;

        #trim string
        $string =~ s/^\s*//;
        $string =~ s/\s*$//;

        #trim first character
        $string     =~ s/^(.)//;
        $first_char = $1;

        #trim send of string
        if ($string =~ /^(.*)$first_char/) {$string = $1;}
        #printf STDERR "fcc: \"%s\" \"%s\"\n", $first_char, $string;

        #convert string
        @hex_code = ();
        @chars    = (split //, $string);

	for ($i=0; $i<=$#chars; $i+=2) {
	#printf STDERR "fcc: i:%d %d\n", $i, $#chars;
	    if ($i < $#chars) {
		push @hex_code, sprintf("%.2X%.2X", ord($chars[$i]),ord($chars[$i+1]));
	    } else {
		push @hex_code, sprintf("%.2X00", ord($chars[$i]));
	    }
            if (defined $$pc_global_ref) {$$pc_global_ref++;}
            if (defined $$pc_local_ref) {$$pc_local_ref++;}
        }
        #set hex code and word count
        $code_entry->[8] = join " ", @hex_code;
        $code_entry->[9] = ($#hex_code + 1);

    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode FCC (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

############
# psop_fcs #
############
sub psop_fcs {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $string;
    my $first_char;
    #hex code
    my $char;
    my @hex_code;
    #temporary

    ##################
    # read arguments #
    ##################
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_string/) {
        $string = $1;

        #trim string
        $string =~ s/^\s*//;
        $string =~ s/\s*$//;

        #trim first character
        $string     =~ s/^(.)//;
        $first_char = $1;

        #trim send of string
        if ($string =~ /^(.*)$first_char/) {$string = $1;}
        #printf STDERR "fcs: \"%s\" \"%s\"\n", $first_char, $string;

         #convert string
        @hex_code = ();
        @chars    = (split //, $string);

	for ($i=0; $i<=$#chars; $i+=2) {
	#printf STDERR "fcs: i:%d %d\n", $i, $#chars;
	    
	    if ($i < ($#chars-1)) {
		push @hex_code, sprintf("%.2X%.2X", ord($chars[$i]),ord($chars[$i+1]));
	    } elsif ($i == ($#chars-1)) {
		push @hex_code, sprintf("%.2X%.2X", ord($chars[$i]),(ord($chars[$i+1])|0x80));
	    } else {
		push @hex_code, sprintf("%.2XFF", (ord($chars[$i])|0x80));
	    }
            if (defined $$pc_global_ref) {$$pc_global_ref++;}
            if (defined $$pc_local_ref) {$$pc_local_ref++;}
        }

        #set hex code and word count
        $code_entry->[8] = join " ", @hex_code;
        $code_entry->[9] = ($#hex_code + 1);

    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode FCS (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

############
# psop_fcz #
############
sub psop_fcz {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $string;
    my $first_char;
    #hex code
    my $char;
    my @hex_code;
    #temporary

    ##################
    # read arguments #
    ##################
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_string/) {
        $string = $1;

        #trim string
        $string =~ s/^\s*//;
        $string =~ s/\s*$//;

        #trim first character
        $string     =~ s/^(.)//;
        $first_char = $1;

        #trim send of string
        if ($string =~ /^(.*)$first_char/) {$string = $1;}
        #printf STDERR "fcs: \"%s\" \"%s\"\n", $first_char, $string;

        #convert string
        @hex_code = ();
        @chars    = (split //, $string);

	for ($i=0; $i<=$#chars; $i+=2) {
	#printf STDERR "fcz: i:%d %d\n", $i, $#chars;
	    
	    if ($i < ($#chars-1)) {
		push @hex_code, sprintf("%.2X%.2X", ord($chars[$i]),ord($chars[$i+1]));
	    } elsif ($i == ($#chars-1)) {
		push @hex_code, sprintf("%.2X%.2X", ord($chars[$i]),ord($chars[$i+1]));
		push @hex_code, "0000";
		if (defined $$pc_global_ref) {$$pc_global_ref++;}
		if (defined $$pc_local_ref) {$$pc_local_ref++;}
	    } else {
		push @hex_code, sprintf("%.2X00", ord($chars[$i]));
	    }
            if (defined $$pc_global_ref) {$$pc_global_ref++;}
            if (defined $$pc_local_ref) {$$pc_local_ref++;}
        }

        #set hex code and word count
        $code_entry->[8] = join " ", @hex_code;
        $code_entry->[9] = ($#hex_code + 1);

    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode FCZ (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

#############
# psop_fill #
#############
sub psop_fill {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $word_count;
    my $word_count_res;
    my $fill_word;
    my $fill_word_res;
    #hex code
    my @hex_code;
    #temporary
    my $error;
    my $value;
    my $i;

    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];
    if ($code_args =~ /$psop_2_args/) {
        $fill_word  = $1;
        $word_count = $2;

        ########################
        # determine word count #
        ########################
        ($error, $word_count_res) = @{$self->evaluate_expression($word_count,
                                                                 $$pc_global_ref,
                                                                 $$pc_local_ref,
                                                                 $$loc_cnt_ref,
						                 $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
        } elsif (! defined $word_count_res) {
            ###################
            # undefined value #
            ###################
            $$pc_global_ref      = undef;
            $$pc_local_ref      = undef;
            $$label_value_ref = undef;
            $$undef_count++;
        } else {
            ####################
            # valid word count #
            ####################
            #######################
            # determine fill word #
            #######################
            ($error, $fill_word_res) = @{$self->evaluate_expression($fill_word,
                                                                    $$pc_global_ref,
                                                                    $$pc_local_ref,
                                                                    $$loc_cnt_ref,
						                    $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                return;
            } elsif (! defined $fill_word_res) {
                ###################
                # undefined value #
                ###################
                if (defined $$pc_global_ref) {$$pc_global_ref = $$pc_global_ref + $word_count_res;}
                if (defined $$pc_local_ref) {$$pc_local_ref = $$pc_local_ref + $word_count_res;}
                #undefine hexcode
                $code_entry->[8] = undef;
                $$undef_count++;
            } else {
                ###################
                # valid fill word #
                ###################
                @hex_code = ();
                foreach $i (1..$word_count_res) {
                    push @hex_code, sprintf("%.4X", ($fill_word_res & 0xffff));
                }
                if (defined $$pc_global_ref) {$$pc_global_ref = $$pc_global_ref + $word_count_res;}
                if (defined $$pc_local_ref) {$$pc_local_ref = $$pc_local_ref + $word_count_res;}
                #set hex code and word count
                $code_entry->[8] = join " ", @hex_code;
                $code_entry->[9] = ($#hex_code + 1);
            }
        }
    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode FILL (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
        $$pc_global_ref = undef;
        $$pc_local_ref = undef;
    }
}

###############
# psop_flet32 #
###############
sub psop_flet32 {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $start_addr;
    my $start_addr_res;
    my $end_addr;
    my $end_addr_res;
    my $c0;
    my $c1;

    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];
    if ($code_args =~ /$psop_2_args/) {
        $start_addr = $1;
        $end_addr   = $2;

	#printf STDERR "RAW: start addr:%s end addr:%s\n", $start_addr, $end_addr;
        ###########################
        # determine start address #
        ###########################
        ($error, $start_addr_res) = @{$self->evaluate_expression($start_addr,
                                                                 $$pc_global_ref,
                                                                 $$pc_local_ref,
                                                                 $$loc_cnt_ref,
						                 $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
        } elsif (! defined $start_addr_res) {
            ###################
            # undefined value #
            ###################
            $$pc_global_ref   = undef;
            $$pc_local_ref    = undef;
            $$label_value_ref = undef;
            $$undef_count_ref++;
        } else {
            #######################
            # valid start address #
            #######################
	    #printf STDERR "start addr found: start addr:%X end addr:%s\n", $start_addr_res, $end_addr;
	    #########################
	    # determine end address #
	    #########################
	    ($error, $end_addr_res) = @{$self->evaluate_expression($end_addr,
								   $$pc_global_ref,
								   $$pc_local_ref,
								   $$loc_cnt_ref,
								   $code_entry->[12])};
	    if ($error) {
		################
		# syntax error #
		################
		$code_entry->[10] = [@{$code_entry->[10]}, $error];
		$$error_count_ref++;
	    } elsif (! defined $end_addr_res) {
		###################
		# undefined value #
		###################
		$$pc_global_ref   = undef;
		$$pc_local_ref    = undef;
		$$label_value_ref = undef;
		$$undef_count_ref++;
	    } else {
		#####################
		# valid end address #
		#####################
		#printf STDERR "end addr found: start addr:%X end addr:%X PC:%X\n", $start_addr_res, $end_addr_res, $$pc_local_ref;		
		#######################################################################
		# make sure that the current PC is not inside the given address range #
		#######################################################################
		if ((($start_addr_res <= $end_addr_res) && ($$pc_local_ref >= $start_addr_res) && ($$pc_local_ref <= $end_addr_res)) ||
		    (($start_addr_res >= $end_addr_res) && ($$pc_local_ref <= $start_addr_res) && ($$pc_local_ref >= $end_addr_res))) {
		    $error = sprintf("recursive FLET16 checksum calculation (%s)",$code_args);
		    $code_entry->[10] = [@{$code_entry->[10]}, $error];
		    $$undef_count_ref++;
		    $$pc_global_ref = undef;
		    $$pc_local_ref = undef;
		} else {
		    #######################
		    # build address space #
		    #######################
		    my %local_addrspace = {};
		    foreach my $code_entry (@{$self->{code}}) {
			#my $code_pc_global   = $code_entry->[6];
			my $code_pc_local   = $code_entry->[7];
			my $code_hex      = $code_entry->[8];
			if (defined $code_pc_local) {
			    my $address = $code_pc_local;
			    if (($code_hex !~ /$cmp_no_hexcode/) &&
				($code_hex !~ /^\s*$/)) {
				foreach my $word (split /\s+/, $code_hex) {
				    if ((($start_addr_res <= $end_addr_res) && ($address >= $start_addr_res) && ($address <= $end_addr_res)) ||
					(($start_addr_res >= $end_addr_res) && ($address <= $start_addr_res) && ($address >= $end_addr_res))) {
					$local_addrspace{$address} = hex($word);
					#printf STDERR "%X: %X (%s)\n", $address, $local_addrspace{$address}, $word;		
				    }
				    $address++;	
				}
			    }
			}
		    }
		    ######################
		    # calculate checksum #
		    ######################
		    $c0 = 0;
		    $c1 = 0;		    
		    my $is_undefined = 0;
		    foreach  my $address ($start_addr_res..$end_addr_res) {			
			if (exists $local_addrspace{$address}) {
			    $c0 += $local_addrspace{$address};
			    $c0 &= 0xffff;
			    $c1 += $c0;
			    $c1 &= 0xffff;
			} else {
			    $is_undefined = 1;
			    last;
			}
			#printf STDERR "C1:%X C0:%X\n", $c1, $c0;		
		    }
		    ##################
		    # add code entry #
		    ##################
		    if (defined $$pc_global_ref) {$$pc_global_ref = ($$pc_global_ref + 2);}
		    if (defined $$pc_local_ref) {$$pc_local_ref = ($$pc_local_ref + 2);}
		    $code_entry->[9] = 2;
		    if ($is_undefined) {
			$code_entry->[8] = "?? ??";
			$$undef_count_ref++;
		    } else {
			$code_entry->[8] = sprintf("%.4X %.4X", $c1, $c0);
		    }
		    $code_entry->[9] = 2;
		}		    
	    }
	}
   } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode FLET16 (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
        $$pc_global_ref = undef;
        $$pc_local_ref = undef;
    }
}

############
# psop_loc #
############
sub psop_loc {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;

    ##################
    # read arguments #
    ##################
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_no_arg/) {

        #increment LOC count
        $$loc_cnt_ref++;

        $code_entry->[8]  = sprintf("\"`\" = %.4d", $$loc_cnt_ref);

    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode LOC (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

############
# psop_org #
############
sub psop_org {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $pc_global;
    my $pc_global_res;
    my $pc_local;
    my $pc_local_res;
    #hex code
    my @hex_code;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];
    #printf STDERR "ORG: code_args=\"%s\"\n",  $code_args;
    #printf STDERR "ORG: 1 arg:  %s\"\n",  ($code_args =~ /$psop_1_arg/) ? "YES" : "NO";
    #printf STDERR "ORG: 2 args: %s\"\n",  ($code_args =~ /$psop_2_arg/) ? "YES" : "NO";   
    for ($code_args) {
        ############
        # local pc #
        ############
        /$psop_1_arg/ && do {
            $pc_local          = $1;
            $code_entry->[8] = "";
            ######################
            # determine local PC #
            ######################
            ($error, $pc_local_res) = @{$self->evaluate_expression($pc_local,
                                                                 $$pc_global_ref,
                                                                 $$pc_local_ref,
                                                                 $$loc_cnt_ref,
						                 $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                #print "$error\n";
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
            } elsif (! defined $pc_local_res) {
                ###################
                # undefined value #
                ###################
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } else {
                ##################
                # valid local pc #
                ##################
                $$pc_local_ref      = $pc_local_res;
                $code_entry->[7]  = $pc_local_res;
                $$label_value_ref = $pc_local_res;
                #######################
                # determine global pc #
                #######################
                if ((($pc_local_res & 0xffff) >= 0x0000) &&
                    (($pc_local_res & 0xffff) <  0x4000)) {
                    #####################
                    # fixed page => $3D #
                    #####################
                    $$pc_global_ref      = ((0x3d * 0x4000) + (($pc_local_res - 0x0000) & 0xffff));
                    $code_entry->[6]  = $$pc_global_ref;
                } elsif ((($pc_local_res & 0xffff) >= 0x4000) &&
                         (($pc_local_res & 0xffff) <  0x8000)) {
                    #####################
                    # fixed page => $3E #
                    #####################
                    $$pc_global_ref      = ((0x3e * 0x4000) + (($pc_local_res - 0x4000) & 0xffff));
                    $code_entry->[6]  = $$pc_global_ref;
                } elsif ((($pc_local_res & 0xffff) >= 0x8000) &&
                         (($pc_local_res & 0xffff) <  0xC000)) {
                    #####################
                    # local memory area #
                    #####################
                    $$pc_global_ref      = (((($pc_local_res >> 16) & 0xff) * 0x4000) + (($pc_local_res - 0x8000) & 0xffff));
                    $code_entry->[6]  = $$pc_global_ref;
                } else {
                    ####################
                    # fixed page => 3F #
                    ####################
                    $$pc_global_ref      = ((0x3f * 0x4000) + (($pc_local_res - 0xc000) & 0xffff));
                    $code_entry->[6]  = $$pc_global_ref;
                }
            }
            last;};
        #######################
        # local and global PC #
        #######################
        /$psop_2_args/ && do {
            $pc_local  = $1;
            $pc_global = $2;
            #printf STDERR "ORG %s ->\n",  $code_args;
            #printf STDERR "ORG %s %s ->\n",  $pc_local, $pc_global;
            $code_entry->[8]  = "";
            ######################
            # determine local PC #
            ######################
            ($error, $pc_local_res) = @{$self->evaluate_expression($pc_local,
                                                                   $$pc_global_ref,
                                                                   $$pc_local_ref,
                                                                   $$loc_cnt_ref,
						                   $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                #print "$error\n";
                $$pc_local_ref      = undef;
                $code_entry->[7]  = undef;
            } elsif (! defined $pc_local_res) {
                ###################
                # undefined value #
                ###################
                $$pc_local_ref      = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } else {
                ##################
                # valid local pc #
                ##################
                $$pc_local_ref      = $pc_local_res;
                $code_entry->[7]  = $pc_local_res;
                $$label_value_ref = $pc_local_res;
            }
            #######################
            # determine global PC #
            #######################
            if ($pc_global =~ /$op_unmapped/) {
                #########################
                # global pc is unmapped #
                #########################
                $$pc_global_ref      = undef;
                $code_entry->[6]  = undef;
            } else {
                #######################
                # evaluate expression #
                #######################
                ($error, $pc_global_res) = @{$self->evaluate_expression($pc_global,
                                                                     $$pc_global_ref,
                                                                     $$pc_local_ref,
                                                                     $$loc_cnt_ref,
						                     $code_entry->[12])};
                if ($error) {
                    ################
                    # syntax error #
                    ################
                    $code_entry->[10] = [@{$code_entry->[10]}, $error];
                    $$error_count_ref++;
                    #print "$error\n";
                    $$pc_global_ref      = undef;
                    $code_entry->[6]  = undef;
                } elsif (! defined $pc_local_res) {
                    ###################
                    # undefined value #
                    ###################
                    $$pc_global_ref      = undef;
                    $code_entry->[6]  = undef;
                } else {
                    ###################
                    # valid global pc #
                    ###################
                    $$pc_global_ref      = $pc_global_res;
                    $code_entry->[6]  = $pc_global_res;
                }
            }
            #printf STDERR "ORG %X %X\n",  $pc_local_res, $pc_global_res;
            last;};
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode ORG (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        #print "$error\n";
        $$error_count_ref++;
        $$pc_global_ref     = undef;
        $$pc_local_ref     = undef;
        $code_entry->[6] = undef;
        $code_entry->[7] = undef;
        $code_entry->[8] = undef;
    }
}

################
# psop_unalign #
################
sub psop_unalign {
    my $self            = shift @_;
    my $pc_global_ref      = shift @_;
    my $pc_local_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    my $bit_mask;
    my $bit_mask_res;
    my $fill_word;
    my $fill_word_res;
    #hex code
    my @hex_code;
    #temporary
    my $error;
    my $value;
    my $count;
    
    ##################
    # read arguments #
    ##################
    $code_args = $code_entry->[5];
    for ($code_args) {
        ############
        # bit mask #
        ############
        /$psop_1_arg/ && do {
            $bit_mask         = $1;
            ######################
            # determine bit mask #
            ######################
            ($error, $bit_mask_res) = @{$self->evaluate_expression($bit_mask,
                                                                   $$pc_global_ref,
                                                                   $$pc_local_ref,
                                                                   $$loc_cnt_ref,
						                   $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } elsif (! defined $bit_mask_res) {
                ###################
                # undefined value #
                ###################
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } elsif (! defined $$pc_local_ref) {
                ######################
                # undefined local PC #
                ######################
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $code_entry->[6]  = undef;
                $code_entry->[7]  = undef;
                $$label_value_ref = undef;
            } else {
                ##################
                # valid bit mask #
                ##################
		$count = 0;
                while (($$pc_local_ref & $bit_mask_res) != $bit_mask_res) {
                    if (defined $$pc_global_ref) {$$pc_global_ref++;}
                    if (defined $$pc_local_ref) {$$pc_local_ref++;}
		    $count++;
                }
                #$code_entry->[6]  = $$pc_global_ref;
                #$code_entry->[7]  = $$pc_local_ref;
                $code_entry->[8]  = "";
                $code_entry->[9]  = $count;
                #$$label_value_ref = $$pc_local_ref;
            }
            last;};
        #######################
        # bit mask, fill word #
        #######################
        /$psop_2_args/ && do {
            $bit_mask = $1;
            $fill_word = $2;
            ######################
            # determine bit mask #
            ######################
            ($error, $bit_mask_res) = @{$self->evaluate_expression($bit_mask,
                                                                   $$pc_global_ref,
                                                                   $$pc_local_ref,
                                                                   $$loc_cnt_ref,
						                   $code_entry->[12])};
            if ($error) {
                ################
                # syntax error #
                ################
                $code_entry->[10] = [@{$code_entry->[10]}, $error];
                $$error_count_ref++;
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $$label_value_ref = undef;
            } elsif (! defined $bit_mask_res) {
                ###################
                # undefined value #
                ###################
                $$pc_global_ref   = undef;
                $$pc_local_ref    = undef;
                $$label_value_ref = undef;
                $$undef_count++;
            } else {
                ##################
                # valid bit mask #
                ##################
                #######################
                # determine fill word #
                #######################
                ($error, $fill_word_res) = @{$self->evaluate_expression($fill_word,
                                                                        $$pc_global_ref,
                                                                        $$pc_local_ref,
                                                                        $$loc_cnt_ref,
						                        $code_entry->[12])};
                if ($error) {
                    ################
                    # syntax error #
                    ################
                    $code_entry->[10] = [@{$code_entry->[10]}, $error];
                    $$error_count_ref++;
                    return;
                } elsif (! defined $fill_word_res) {
                    ###################
                    # undefined value #
                    ###################
                    while (~$$pc_local_ref & $bit_mask_res) {
                        if (defined $$pc_global_ref) {$$pc_global_ref++;}
                        if (defined $$pc_local_ref) {$$pc_local_ref++;}
                    }
                    #$$label_value_ref = $$pc_local_ref;
                    #undefine hexcode
                    $code_entry->[8] = undef;
                    $$undef_count++;
                } else {
                    ###################
                    # valid fill word #
                    ###################
                    @hex_code = ();
                    while (($$pc_local_ref & $bit_mask_res) != $bit_mask_res) {
                        if (defined $$pc_global_ref) {$$pc_global_ref++;}
                        if (defined $$pc_local_ref) {$$pc_local_ref++;}
                        push @hex_code, sprintf("%.4X", ($fill_word_res & 0xffff));
                    }
                    #set hex code and word count
                    $code_entry->[8] = join " ", @hex_code;
                    $code_entry->[9] = ($#hex_code + 1);
                }
            }
            last;};
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode UNALIGN (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
        $$pc_global_ref  = undef;
        $$pc_local_ref   = undef;
        $code_entry->[8] = undef;
    }
}

##############
# psop_setdp #
##############
sub psop_setdp {
    my $self            = shift @_;
    my $pc_lin_ref      = shift @_;
    my $pc_pag_ref      = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    #arguments
    my $code_args;
    #temporary
    my $error;
    my $value;

    ##################
    # read arguments #
    ##################
    $code_label = $code_entry->[1];
    $code_args  = $code_entry->[5];

    ##################
    # check argument #
    ##################
    if ($code_args =~ /$psop_1_arg/) {
        ################
        # one argument #
        ################
        ($error, $value) = @{$self->evaluate_expression($1,
                                                        $$pc_lin_ref,
                                                        $$pc_pag_ref,
                                                        $$loc_cnt_ref,
						        $code_entry->[12])};
        if ($error) {
            ################
            # syntax error #
            ################
            $code_entry->[10] = [@{$code_entry->[10]}, $error];
            $$error_count_ref++;
        } else {
            ##################
            # valid argument #
            ##################
            #set direct page
            $self->{dir_page} = $value;
            $code_entry->[8]  = sprintf("DIRECT PAGE = \$%2X:", $value);
        }
    } else {
        ################
        # syntax error #
        ################
        $error = sprintf("invalid argument for pseudo opcode CPU (%s)",$code_args);
        $code_entry->[10] = [@{$code_entry->[10]}, $error];
        $$error_count_ref++;
    }
}

###############
# psop_ignore #
###############
sub psop_ignore {
    my $self            = shift @_;
    my $pc_global_ref   = shift @_;
    my $pc_local_ref    = shift @_;
    my $loc_cnt_ref     = shift @_;
    my $error_count_ref = shift @_;
    my $undef_count_ref = shift @_;
    my $label_value_ref = shift @_;
    my $code_entry      = shift @_;

    ##################
    # valid argument #
    ##################
    #check if symbol already exists
    $code_entry->[8]  = sprintf("IGNORED!");
}

########################
# address mode ckecker #
########################

################
# check_n1_inh #
################
sub check_n1_inh {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    my @hex;
    my $last_word;

    if ($arg_ref->[0] =~ /;\s*$/) {
	#printf STDERR "INH: \"%s\"\n", $$hex_ref;
	@hex        = split(/\s/, $$hex_ref);
	#printf STDERR "INH: \"%s\"\n", join(",", @hex);	
	$last_word  = hex(pop @hex);
	$last_word |= 0x8000;
	#printf STDERR "INH: %.4X\n", $last_word;	
	push @hex, sprintf("%.4X", $last_word);
        $$result_ref = join(" ", @hex);
        return 1;
    } else {
	#don't append semicolon
	$$result_ref = $$hex_ref;
        return 1;
    }
}

##################
# check_n1_abs14 #
##################
sub check_n1_abs14 {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
    
    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if ($value < 0x3FFF) {
	    #printf STDERR "ABS14: address in range (%.4X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "ABS14: address out of range (%.4X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	}
    } else {
	#printf STDERR "ABS14: address yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

##################
# check_n1_rel13 #
##################
sub check_n1_rel13 {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;
    my $offset;
    my @hex;
    my $last_word;
 
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};

    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	$offset = $value - $pc_local - 1;
	if (($offset >= -0xFFE) && ($offset <= 0xFFF)) {
	    #printf STDERR "REL13: address offset in range (%.4X)\n", $offset;
	    $last_word |= $offset;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "REL13: address out of range (%.4X)\n", $offset;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    #return 1;
	    return 0;
	}
    } else {
	#printf STDERR "REL13: address yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

################
# check_n1_lit #
################
sub check_n1_lit {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;   
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
    
    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if (($offset >= -0x7FE) && ($offset <= 0x7FF)) {
	    #printf STDERR "LIT value in range (%.3X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} elsif (($offset >= -0x7FFE) && ($offset <= 0x7FFF)) {
	    #printf STDERR "LIT value in range (%.4X)\n", $value;
	    $last_word |= ($value & 0xFFF);
	    push @hex, sprintf("%.4X", $last_word);
	    $last_word = 0x0F80 | ($value >> 12);
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "LIT value out of range (%.2X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	}
    } else {
	#printf LIT value yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

##################
# check_n1_uimm5 #
##################
sub check_n1_uimm5 {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
    
    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if (($value > 0x00) && ($value <= 0x1F)) {
	    #printf STDERR "UIMM5 value in range (%.2X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "UIMM5 value out of range (%.2X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	}
    } else {
	#printf STDERR "UIMM5 value yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

##################
# check_n1_simm5 #
##################
sub check_n1_simm5 {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;   
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
    
    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if (($value >= -16) && ($value <= 15) && ($value != 0)) {
	    $value &= 0x1F;
	    #printf STDERR "SIMM5 value in range (%.2X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "SIMM5 value out of range (%.2X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	}
    } else {
	#printf STDERR "UIMM5 value yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

################
# check_n1_oimm5 #
################
sub check_n1_oimm5 {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;   
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};
    
    #printf STDERR "arg:   \"%s\"\n", $arg_ref->[0];
    #printf STDERR "error: \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if (($value >= -15) && ($value <= 15)) {
	    if ($value < 0) {
		$value--;
	    }
	    $value &= 0x1F;
	    #printf STDERR "OIMM5 value in range (%.2X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "OIMM5 value out of range (%.2X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	}
    } else {
	#printf STDERR "OIMM5 value yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

##################
# check_n1_stack #
##################
sub check_n1_stack {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my @hex;
    my $last_word;
    my $ips_ps3;
    my $ps3_ps2;
    my $ps2_ps1;
    my $ps1_ps0;
    my $ps1_ps0;
    my $ps0_rs0;
    my $rs0_irs;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);

    #printf STDERR "STACK! (%s)\n", join(",",@$arg_ref);

    $ips_ps3 = $arg_ref->[0];
    $ps3_ps2 = $arg_ref->[1];
    $ps2_ps1 = $arg_ref->[2];
    $ps1_ps0 = $arg_ref->[3];
    $ps1_ps0 = $arg_ref->[4];
    $ps0_rs0 = $arg_ref->[5];
    $rs0_irs = $arg_ref->[6];

    #printf STDERR "STACK: %s PS3 %s PS2 %s PS1 %s PS0 %s RS0 %s\n", $ips_ps3,
    #                                                                $ps3_ps2,
    #                                                                $ps2_ps1,
    #                                                                $ps1_ps0,
    #                                                                $ps1_ps0,
    #                                                                $ps0_rs0,
    #                                                                $rs0_irs;

    #Flag invalid patterns
    if (($ips_ps3 =~ /<-/)  && ($ps3_ps2 =~ /\s+/) ||
	($ips_ps3 =~ /<-/)  && ($ps3_ps2 =~ /->/)  ||
	($ips_ps3 =~ /->/)  && ($ps3_ps2 =~ /<>/)  ||
	($ips_ps3 =~ /->/)  && ($ps3_ps2 =~ /<-/)  ||
	($ps0_rs0 =~ /\s+/) && ($rs0_irs =~ /\->/) ||
	($ps0_rs0 =~ /<-/)  && ($rs0_irs =~ /\->/) ||
	($ps0_rs0 =~ /<>/)  && ($rs0_irs =~ /\<-/) ||
	($ps0_rs0 =~ /->/)  && ($rs0_irs =~ /\<-/)) {
	#printf STDERR "STACK: invalid pattern\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	return 0;
    } else {

	#Insert pattern in hex code 
	$last_word |= ($ips_ps3 =~ /<-/) ? 0x200 : 0x000;
	$last_word |= ($ips_ps3 =~ /->/) ? 0x200 : 0x000;
	$last_word |= ($ps3_ps2 =~ /<-/) ? 0x100 : 0x000;
	$last_word |= ($ps3_ps2 =~ /->/) ? 0x080 : 0x000;
	$last_word |= ($ps3_ps2 =~ /<>/) ? 0x180 : 0x000;
	$last_word |= ($ps2_ps1 =~ /<-/) ? 0x040 : 0x000;
	$last_word |= ($ps2_ps1 =~ /->/) ? 0x020 : 0x000;
	$last_word |= ($ps2_ps1 =~ /<>/) ? 0x060 : 0x000;
	$last_word |= ($ps1_ps0 =~ /<-/) ? 0x010 : 0x000;
	$last_word |= ($ps1_ps0 =~ /->/) ? 0x008 : 0x000;
	$last_word |= ($ps1_ps0 =~ /<>/) ? 0x018 : 0x000;
	$last_word |= ($ps0_rs0 =~ /<-/) ? 0x004 : 0x000;
	$last_word |= ($ps0_rs0 =~ /->/) ? 0x002 : 0x000;
	$last_word |= ($ps0_rs0 =~ /<>/) ? 0x006 : 0x000;
	$last_word |= ($rs0_irs =~ /<-/) ? 0x001 : 0x000;
	$last_word |= ($rs0_irs =~ /->/) ? 0x001 : 0x000;
	
	push @hex, sprintf("%.4X", $last_word);
	$$result_ref = join(" ", @hex);
	return 1;
    } 
}

################
# check_n1_mem #
################
sub check_n1_mem {
    my $self       = shift @_;
    my $arg_ref    = shift @_;
    my $pc_global  = shift @_;
    my $pc_local   = shift @_;
    my $loc_cnt    = shift @_;
    my $sym_tabs   = shift @_;
    my $hex_ref    = shift @_;
    my $error_ref  = shift @_;
    my $result_ref = shift @_;
    #temporary
    my $value;
    my @hex;
    my $last_word;
   
    ($$error_ref, $value) = @{$self->evaluate_expression($arg_ref->[0], $pc_global, $pc_local, $loc_cnt, $sym_tabs)};

    $value = $value - ($self->{dir_page} & 0xFF00);
    
    #printf STDERR "MEM dir_page: \"%X\"\n", $self->{dir_page};
    #printf STDERR "MEM arg:      \"%s\"\n", $arg_ref->[0];
    #printf STDERR "MEM error:    \"%s\" value:%X\n", $$error_ref, $value;

    @hex        = split(/\s/, $$hex_ref);
    $last_word  = hex(pop @hex);
    
    if (defined $value) {
	if ($value < 0xFF) {
	    #printf STDERR "MEM: address in range (%.2X)\n", $value;
	    $last_word |= $value;
	    if ($arg_ref->[1] =~ /;\s*$/) {
		$last_word |= 0x8000;
	    }
	    push @hex, sprintf("%.4X", $last_word);
	    $$result_ref = join(" ", @hex);
	    return 1;
	} else {
	    #printf STDERR "MEM: address out of range (%.2X)\n", $value;
	    push @hex, "????";
	    $$result_ref = join(" ", @hex);
	    return 0;
	    #$undef_count++;
	    #return 1;
	}
    } else {
	#printf STDERR "MEM: address yet unknown\n";
	push @hex, "????";
	$$result_ref = join(" ", @hex);
	$undef_count++;
	return 1;
    }
}

1;
