#! /usr/local/bin/perl

# For CVS:
# $Date: 2003/11/18 00:57:20 $
#
# $Id: cvsdir.pm,v 1.1 2003/11/18 00:57:20 buddy Exp $
# $Revision: 1.1 $

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
use warnings;


use constant WORKING_DIR => '/home/' .
		scalar(exists $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : $ENV{USER}) .
		'/proj/T3';


###########################
# Return a true value:
###########################

1;
