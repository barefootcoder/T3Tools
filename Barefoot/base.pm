#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::base
#
###########################################################################
#
# This module should be ideally included by other Barefoot:: modules, but
# could be included separately if need be.  It defines the DEBUG constant,
# which is turned on by Barefoot::debug.  It also defines the constants
# true and false, whose utility should be self-evident.
#
# Note that the same chicken-and-egg problem you have with testing
# Barefoot::debug applies to Barefoot::base as well; you can't get the
# version of base.pm from your CVS working directory as you can with other
# modules.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package main;

### Private ###############################################################

use strict;


use constant DEBUG_MODE => 0;
use constant true => 1;
use constant false => 0;


1;


#
# Subroutines:
#


