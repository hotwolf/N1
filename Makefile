###############################################################################
# N1 - Makefile                                                               #
###############################################################################
#    Copyright 2018 Dirk Heisswolf                                            #
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
#    This is the project makefile to run all verifcation and documentation    #
#    tasks. A description of all supported rules is given in the help text.   #
#                                                                             #
###############################################################################
# Version History:                                                            #
#   December 4, 2018                                                          #
#      - Initial release                                                      #
###############################################################################

#Directories
REPO_DIR      := .
#REPO_DIR     := $(CURDIR)
RTL_DIR       := $(REPO_DIR)/rtl/verilog
BENCH_DIR     := $(REPO_DIR)/bench/verilog
YOSYS_DIR     := $(REPO_DIR)/tools/Yosys
YOSYS_SRC_DIR := $(YOSYS_DIR)/src
YOSYS_WRK_DIR := $(YOSYS_DIR)/run
SBY_DIR       := $(REPO_DIR)/tools/SymbiYosys
SBY_SRC_DIR   := $(SBY_DIR)/src
SBY_WRK_DIR   := $(SBY_DIR)/run
GTKW_DIR      := $(REPO_DIR)/tools/gtkwave
GTKW_SRC_DIR  := $(GTKW_DIR)/src
GTKW_WRK_DIR  := $(GTKW_DIR)/run

#Tools	      
ifndef EDITOR 
EDITOR        := $(shell which emacs || which xemacs || which nano || which vi)
endif	      
VERILATOR     := verilator -sv --lint-only 
IVERILOG      := iverilog -t null
#YOSYS         := yosys -q
YOSYS         := yosys
SBY           := sby -f
PERL          := perl
GTKWAVE       := gtkwave      
VCD2FST       := vcd2fst

#List of modules and their supported configurations <module>.<configuration>
MODCONFS := 	$(sort	N1.default \
			N1.iCE40UP5K \
			N1_alu.default \
			N1_dsp_synth.default \
			N1_dsp_iCE40UP5K.default \
			N1_excpt.default \
			N1_fc.default \
			N1_ir.default \
			N1_pagu.default \
			N1_prs.default \
			N1_sagu.default \
			SB_MAC16.default \
		 )

MODS  := $(sort $(foreach modconf,$(MODCONFS),$(firstword $(subst ., ,$(modconf)))))
CONFS := $(sort $(foreach modconf,$(MODCONFS),$(lastword  $(subst ., ,$(modconf)))))

.SECONDEXPANSION:

#############
# Help text #
#############
help:
	$(info This makefile supports the following targets:)
	$(info )
	$(info lint:                            Lint all modules in all supported configurations)
	$(info lint.<module>.<configuration>:   Lint a module in one particular configuration)
	$(info lint.<module>:                   Lint a module in all supported configurations)
	$(info lint.<configuration>:            Lint all modules which support the given configuration)
	$(info lint.clean:                      Clean up lint targets)
#	$(info )
#	$(info verify:                          Verify all modules in all supported configurations)
#	$(info verify.<module>.<configuration>: Verify a module in one particular configuration)
#	$(info verify.<module>:                 Verify a module in all supported configurations)
#	$(info verify.<configuration>:          Verify all modules which support the given configuration)
#	$(info verify.clean:                    Clean up verify targets)
#	$(info )
#	$(info bmc:                             Generate bounded proofs for all modules in all support configurations)
#	$(info bmc.<module>.<configuration>:    Generate bounded proofs for a module in one particular configuration)
#	$(info bmc.<module>:                    Generate bounded proofs for a module in all supported configurations)
#	$(info bmc.<configuration>:             Generate bounded proofs for all modules which support the given configuration)
#	$(info bmc.clean:                       Clean up bounded proof targets)
#	$(info )
#	$(info prove:                           Generate unboundeds proof for all modules in all supported configurations)
#	$(info prove.<module>.<configuration>:  Generate unboundeds proof for a module in one particular configuration)
#	$(info prove.<module>:                  Generate unboundeds proof for a module in all supported configurations)
#	$(info prove.<configuration>:           Generate unboundeds proof for all modules which support the given configuration)
#	$(info prove.clean:                     Clean up unbounded proof targets)
#	$(info )
#	$(info live:                            Prove liveness of all modules in all supported configurations)
#	$(info live.<module>.<configuration>:   Prove liveness of a module in one particular configuration)
#	$(info live.<module>:                   Prove liveness of a module in all supported configurations)
#	$(info live.<configuration>:            Prove liveness of all modules which support the given configuration)
#	$(info live.clean:                      Clean up liveness targets)
#	$(info )
#	$(info cover:                           Generate cover traces for all modules in all supported configurations)
#	$(info cover.<module>.<configuration>:  Generate cover traces for a module in one particular configuration)
#	$(info cover.<module>:                  Generate cover traces for a module in all supported configurations)
#	$(info cover.<configuration>:           Generate cover traces for all modules which support the given configuration)
#	$(info cover.clean:                     Clean up cover targets)
#	$(info )
#	$(info debug.list:                      List all available VCD dump files)
#	$(info debug:                           View the most recent VCD dump file)
#	$(info debug.prev:                      View the previous VCD dump file)
#	$(info debug<n>:                        View a VCD dump file from the selection given by 'debug.list')
#	$(info )
	$(info synth:                           Run all synthesis scripts)
	$(info synth.<module>.<configuration>:  Run the synthesys script of a module in one particular configuration)
	$(info synth.<module>:                  Run all synthesys scripts of a module)
	$(info synth.<configuration>:           Run the synthesys scripts of all modules which support the given configuration)
	$(info synth.list:                      List all synthesis scripts)
	$(info synth.clean:                     Clean up synthesis outputs)
	$(info )
##	$(info clean:                           Clean up all targets)
#	$(info )
#	$(info doc:                             Build the user manual)
	@echo "" > /dev/null

###########
# Linting #
###########
LINT_MODCONFS := $(MODCONFS:%=lint.%)
LINT_MODS     := $(MODS:%=lint.%)
LINT_CONFS    := $(CONFS:%=lint.%)

$(LINT_MODCONFS): 
	$(eval mod      := $(word 2,$(subst ., ,$@)))
	$(eval commod   := $(patsubst N1_dsp_%,N1_dsp,${mod}))
	$(eval conf     := $(lastword $(subst ., ,$@)))
	$(eval confdef  := CONF_$(shell echo $(conf) | tr '[:lower:]' '[:upper:]'))
	$(eval srcfiles := $(BENCH_DIR)/ftb_$(commod).sv $(RTL_DIR)/$(mod).v)
#	$(eval srcfiles += $(shell if [ "$@" = "lint.N1.default" ];   then echo $(RTL_DIR)/N1_dsp_synth.v;     fi;))  	
#	$(eval srcfiles += $(shell if [ "$@" = "lint.N1.iCE40UP5K" ]; then echo $(RTL_DIR)/N1_dsp_iCE40UP5K.v; fi;))  	
	$(eval srcfiles += $(if $(findstring lint.N1.default,$@),$(RTL_DIR)/N1_dsp_synth.v))  	
	$(eval srcfiles += $(if $(findstring lint.N1.iCE40UP5K,$@),$(RTL_DIR)/N1_dsp_iCE40UP5K.v))  	
	$(info ...Linting $(mod) in $(conf) configuration)
	@$(VERILATOR) -D$(confdef) --top-module ftb_$(commod) -y $(RTL_DIR) $(srcfiles) 
	@$(IVERILOG) -D$(confdef) -s ftb_$(commod) -y $(RTL_DIR) $(srcfiles)  
	@$(YOSYS) -q -p "read_verilog -sv -D $(confdef) -I $(RTL_DIR) $(srcfiles)"

$(LINT_MODS): $$(filter $$@.%,$(LINT_MODCONFS))

$(LINT_CONFS): $$(filter lint.%.$$(lastword $$(subst ., ,$$@)),$(LINT_MODCONFS))

lint:	$(LINT_MODCONFS) 

lint.clean:

################################
# Complete formal verification #
################################
VERIFY_MODCONFS := $(MODCONFS:%=verify.%)
VERIFY_MODS     := $(MODS:%=verify.%)
VERIFY_CONFS    := $(CONFS:%=verify.%)

$(VERIFY_MODCONFS): $$(subst verify.,bmc.,$$@) $$(subst verify.,prove.,$$@) $$(subst verify.,cover.,$$@) #$$(subst verify.,live.,$$@)

$(VERIFY_MODS): $$(filter $$@.%,$(VERIFY_MODCONFS))

$(VERIFY_CONFS): $$(filter verify.%.$$(lastword $$(subst ., ,$$@)),$(VERIFY_MODCONFS))

verify:	$(VERIFY_MODCONFS) 

verify.clean: bmc.clean prove.clean cover.clean live.clean

##################
# Bounded proofs #
##################
BMC_MODCONFS := $(MODCONFS:%=bmc.%)
BMC_MODS     := $(MODS:%=bmc.%)
BMC_CONFS    := $(CONFS:%=bmc.%)

$(BMC_MODCONFS):
	$(eval mod     := $(word 2,$(subst ., ,$@)))
	$(eval conf    := $(lastword $(subst ., ,$@)))
	$(info ...Generating bounded proofs for $(mod) in $(conf) configuration)
	@$(SBY) -d $(SBY_WRK_DIR)/$@ $(SBY_SRC_DIR)/$(mod).sby bmc.$(conf)

$(BMC_MODS): $$(filter $$@.%,$(BMC_MODCONFS))

$(BMC_CONFS): $$(filter bmc.%.$$(lastword $$(subst ., ,$$@)),$(BMC_MODCONFS))

bmc: $(BMC_MODCONFS) 

bmc.clean:
	$(info...Cleaning up bounded proof targets)
	@rm -rf $(BMC_MODCONFS:%=$(SBY_WRK_DIR)/%)

###################
# Unounded proofs #
###################
PROVE_MODCONFS := $(MODCONFS:%=prove.%)
PROVE_MODS     := $(MODS:%=prove.%)
PROVE_CONFS    := $(CONFS:%=prove.%)

$(PROVE_MODCONFS):
	$(eval mod     := $(word 2,$(subst ., ,$@)))
	$(eval conf    := $(lastword $(subst ., ,$@)))
	$(info ...Generating unbounded proofs $(mod) in $(conf) configuration)
	@$(SBY) -d $(SBY_WRK_DIR)/$@ $(SBY_SRC_DIR)/$(mod).sby prove.$(conf)

$(PROVE_MODS): $$(filter $$@.%,$(PROVE_MODCONFS))

$(PROVE_CONFS): $$(filter prove.%.$$(lastword $$(subst ., ,$$@)),$(PROVE_MODCONFS))

prove:	$(PROVE_MODCONFS) 

prove.clean:
	$(info ...Cleaning up unbounded proof targets)
	@rm -rf $(PROVE_MODCONFS:%=$(SBY_WRK_DIR)/%)

############
# Liveness #
############
LIVE_MODCONFS := $(MODCONFS:%=live.%)
LIVE_MODS     := $(MODS:%=live.%)
LIVE_CONFS    := $(CONFS:%=live.%)

$(LIVE_MODCONFS):
	$(eval mod     := $(word 2,$(subst ., ,$@)))
	$(eval conf    := $(lastword $(subst ., ,$@)))
	$(info ...Proving liveness of $(mod) in $(conf) configuration)
	@$(SBY) -f -d $(SBY_WRK_DIR)/$@ $(SBY_SRC_DIR)/$(mod).sby live.$(conf)

$(LIVE_MODS): $$(filter $$@.%,$(LIVE_MODCONFS))

$(LIVE_CONFS): $$(filter live.%.$$(lastword $$(subst ., ,$$@)),$(LIVE_MODCONFS))

live:	$(LIVE_MODCONFS) 

live.clean:
	$(info ...Cleaning up liveness targets)
	@rm -rf $(LIVE_MODCONFS:%=$(SBY_WRK_DIR)/%)

################
# Cover traces #
################
COVER_MODCONFS := $(MODCONFS:%=cover.%)
COVER_MODS     := $(MODS:%=cover.%)
COVER_CONFS    := $(CONFS:%=cover.%)

$(COVER_MODCONFS):
	$(eval mod     := $(word 2,$(subst ., ,$@)))
	$(eval conf    := $(lastword $(subst ., ,$@)))
	$(info ...Generating cover traces for $(mod) in $(conf) configuration)
	@$(SBY) -d $(SBY_WRK_DIR)/$@ $(SBY_SRC_DIR)/$(mod).sby cover.$(conf)

$(COVER_MODS): $$(filter $$@.%,$(COVER_MODCONFS))

$(COVER_CONFS): $$(filter cover.%.$$(lastword $$(subst ., ,$$@)),$(COVER_MODCONFS))

cover:	$(COVER_MODCONFS) 

cover.clean:
	$(info ...Cleaning up cover targets)
	@rm -rf $(COVER_MODCONFS:%=$(SBY_WRK_DIR)/%)

#########
# Debug #
#########
VCD_FILES          := $(shell find $(SBY_WRK_DIR) -name "*.vcd" -type f -exec ls -1t "{}" +;)
FST_FILES          := $(VCD_FILES:%.vcd=%.fst)
GTKW_FILES         := $(VCD_FILES:%.vcd=%.gtkw)
STEMS_FILES        := $(VCD_FILES:%.vcd=%.stems)
TRACE_DIRS         := $(dir $(VCD_FILES))
DEBUG_DIRS         := $(dir $(patsubst %/,%,$(TRACE_DIRS)))
DEBUG_TGTS         :=
$(foreach x,$(VCD_FILES),$(eval DEBUG_TGTS := $(DEBUG_TGTS) debug$(words $(DEBUG_TGTS) x)))

$(FST_FILES): %.fst: %.vcd
	$(info ...Converting VCD to FST)
	@$(VCD2FST) $< $@

$(STEMS_FILES): %.stems: %.fst $(BENCH_DIR)/*.sv $(RTL_DIR)/*.v
	$(eval dir_name := $(notdir $(patsubst %/,%,$(dir $(patsubst %/,%,$(dir $@))))))
	$(eval mod      := $(word 2,$(subst ., ,$(dir_name))))
	$(eval conf     := $(lastword $(subst ., ,$(dir_name))))
	$(eval confdef  := CONF_$(shell echo $(conf) | tr '[:lower:]' '[:upper:]'))
	$(info dir_name: $(dir_name))
	$(info mod:      $(mod))
	$(info conf:     $(conf))
	$(info confdef:  $(confdef))
	$(info ...Generating STEMS file)
	@$(PERL) tools/gtkwave/src/gtkw_gen.pl \
		-top   ftb_$(mod) \
		-trace $< \
		-gtkw  $(subst .stems,.gtkw,$@) \
		-stems $@ \
		+define+$(confdef) \
		+define+FORMAL \
		+libext+.v+.sv \
		-y $(BENCH_DIR) \
		-y $(RTL_DIR) \
		$(BENCH_DIR)/ftb_$(mod).sv

$(GTKW_FILES): %.gtkw: %.fst $(BENCH_DIR)/*.sv $(RTL_DIR)/*.v
	$(eval dir_name := $(notdir $(patsubst %/,%,$(dir $(patsubst %/,%,$(dir $@))))))
	$(eval mod      := $(word 2,$(subst ., ,$(dir_name))))
	$(eval conf     := $(lastword $(subst ., ,$(dir_name))))
	$(eval confdef  := CONF_$(shell echo $(conf) | tr '[:lower:]' '[:upper:]'))
	$(info dir_name: $(dir_name))
	$(info mod:      $(mod))
	$(info conf:     $(conf))
	$(info confdef:  $(confdef))
	$(info ...Generating GTKW file)
	@$(PERL) tools/gtkwave/src/gtkw_gen.pl \
		-top   ftb_$(mod) \
		-trace $< \
		-gtkw  $@ \
		-stems $(subst .gtkw,.stems,$@) \
		+define+$(confdef) \
		+define+FORMAL \
		+libext+.v+.sv \
		-y $(BENCH_DIR) \
		-y $(RTL_DIR) \
		$(BENCH_DIR)/ftb_$(mod).sv

$(DEBUG_TGTS): $$(word $$(subst debug,,$$@),$(STEMS_FILES)) \
               $$(word $$(subst debug,,$$@),$(FST_FILES)) \
               $$(word $$(subst debug,,$$@),$(GTKW_FILES))
	$(info ...Opening GTKWave)
	@$(GTKWAVE) -t $< $(word 2,$^) $(word 3,$^) &
	$(info ...Opening log file)
	$(eval logs = $(shell find $(dir $(word 2,$^)).. -name "logfile*.txt" -type f -exec ls -1t "{}" +;))
	@echo $(logs)
#	@$(EDITOR) $(firstword $(logs)) &

debug: $(firstword $(DEBUG_TGTS))

debug.prev: $(word 2,$(DEBUG_TGTS))

debug.list:
ifeq ($(words $(DEBUG_TGTS)), 0)
	$(info No debug targets available)
else
ifeq ($(words $(DEBUG_TGTS)), 1)
	$(info The following VCD file is available for viewing:)
else
	$(info The following $(words $(DEBUG_TGTS)) VCD files are available for viewing:)
endif
endif
	@$(foreach tgt,$(DEBUG_TGTS),$(info $(tgt):     $(word $(subst debug,,$(tgt)),$(VCD_FILES))))
ifneq ($(firstword $(DEBUG_TGTS)),)
	$(info debug:      --> debug1 (most recent VCD dump))
endif
ifneq ($(word 2,$(DEBUG_TGTS)),)
	$(info debug.prev: --> debug2 (previous VCD dump))
endif
	@echo "" > /dev/null

#############
# Synthesis #
#############
SYNTH_SCRIPTS  := $(sort $(shell ls -1 $(YOSYS_SRC_DIR)/*.yosys))
SYNTH_MODCONFS := $(addprefix synth.,$(filter $(basename $(notdir $(SYNTH_SCRIPTS))),$(MODCONFS)))
SYNTH_MODS     := $(addprefix synth.,$(sort $(foreach modconf,$(SYNTH_MODCONFS),$(word 2,$(subst ., ,$(modconf))))))
SYNTH_CONFS    := $(addprefix synth.,$(sort $(foreach modconf,$(SYNTH_MODCONFS),$(lastword  $(subst ., ,$(modconf))))))

$(SYNTH_MODCONFS):
	$(eval mod     := $(word 2,$(subst ., ,$@)))
	$(eval conf    := $(lastword $(subst ., ,$@)))
	$(YOSYS) -s $(YOSYS_SRC_DIR)/$(mod).$(conf).yosys

$(SYNTH_MODS): $$(filter $$@.%,$(SYNTH_MODCONFS))

$(SYNTH_CONFS): $$(filter synth.%.$$(lastword $$(subst ., ,$$@)),$(SYNTH_MODCONFS))

synth:	$(SYNTH_MODCONFS) 

synth.list:
	@ls -1 $(SYNTH_SCRIPTS)

synth.clean:
	$(info ...Cleaning up synthesis files)
	@rm -rf $(YOSYS_WRK_DIR)/*

#################
# Documentation #
#################
doc:
	$(MAKE) -C $(DOC_SRC_DIR)

############
# Clean up #
############

clean:	lint.clean bmc.clean verify.clean synth.clean

####################
# General targetds #
####################

.PHONY:	help \
	$(LINT_MODCONFS)   $(LINT_MODS)   $(LINT_CONFS)   lint   lint.clean \
	$(VERIFY_MODCONFS) $(VERIFY_MODS) $(VERIFY_CONFS) verify verify.clean \
	$(BMC_MODCONFS)    $(BMC_MODS)    $(BMC_CONFS)    bmc    bmc.clean \
	$(PROVE_MODCONFS)  $(PROVE_MODS)  $(PROVE_CONFS)  prove  prove.clean \
	$(LIVE_MODCONFS)   $(LIVE_MODS)   $(LIVE_CONFS)   live   live.clean \
	$(COVER_MODCONFS)  $(COVER_MODS)  $(COVER_CONFS)  cover  cover.clean \
	$(DEBUG_TGTS) debug debug.prev debug.list \
	$(SYNTH_MODCONFS)  $(SYNTH_MODS)  $(SYNTH_CONFS)  synth  synth.clean \
	doc \
	clean
