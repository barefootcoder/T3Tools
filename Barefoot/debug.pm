#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# debug
#
###########################################################################
#
# Include this module to indicate your Perl script is running in test mode.
# This causes various defaults to change, most notably the directory from
# which standard Barefoot Perl modules are drawn, which changes from
# /usr/local/barefoot to ~/proj/perl_mod.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package Barefoot::debug;

### Private ###############################################################

use strict;

use Barefoot::cvs;

use lib (cvs::WORKING_DIR . "/perl_mod");


$::debug = 1;

1;


#
# Subroutines:
#


