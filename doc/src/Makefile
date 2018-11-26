###############################################################################
# N1 - Documentation Makefile                                                 #
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
#    This is the makefile to build the N1 user manual.                        #
#                                                                             #
###############################################################################
# Version History:                                                            #
#   November 26, 2018                                                         #
#      - Initial release                                                      #
###############################################################################

#Document name
DOC_NAME    := N1_manual

#Directories
REPO_DIR    := ../..
#REPO_DIR   := $(CURDIR)/../..
DOC_DIR     := ..
#DOC_DIR    := $(REPU_DIR)/doc
SRC_DIR     := $(DOC_DIR)/src
BUILD_DIR   := $(DOC_DIR)/run
PUBLISH_DIR := $(DOC_DIR)

#Build tasks
publish: $(PUBLISH_DIR)/$(DOC_NAME).pdf

build:   $(BUILD_DIR)/$(DOC_NAME).pdf

preview: 	
	latexmk -f -pdf -pv -outdir=$(BUILD_DIR) -auxdir=$(BUILD_DIR) $(SRC_DIR)/$(DOC_NAME).tex

clean:
	rm $(BUILD_DIR)/*

#Files
$(PUBLISH_DIR)/$(DOC_NAME).pdf:  $(BUILD_DIR)/$(DOC_NAME).pdf
	cp $(BUILD_DIR)/$(DOC_NAME).pdf $(PUBLISH_DIR)/$(DOC_NAME).pdf

$(BUILD_DIR)/$(DOC_NAME).pdf: $(SRC_DIR)/*.tex $(SRC_DIR)/*.bib
	latexmk -f -pdf -outdir=$(BUILD_DIR) -auxdir=$(BUILD_DIR) $(SRC_DIR)/$(DOC_NAME).tex

#Phony goals
.PHONY:	preview clean

#Forced goals
FORCE:
