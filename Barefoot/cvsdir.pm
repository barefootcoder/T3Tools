#! /usr/local/bin/perl -w

# For CVS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::cvsdir
#
###########################################################################
#
# This is needed by both cvs.pm and debug.pm (q.v.).  It has to be separate
# because cvs.pm includes base.pm, so if debug.pm includes cvs.pm, you get
# a heinous chicken-and-egg problem: base.pm sets the master debug variable
# before debug.pm has a chance to, so then debug.pm thinks it doesn't need
# to set it, so the master debug variable is always zero.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2003 Barefoot Software.
#
###########################################################################

package cvs;

### Private ###############################################################

use strict;


use constant WORKING_DIR => "/proj/" .
		scalar(exists $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : $ENV{USER});


###########################
# Return a true value:
###########################

1;
