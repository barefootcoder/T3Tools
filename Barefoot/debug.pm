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
# /usr/local/barefoot to /proj/$USER/barefoot/perl_mod.
#
# In order for this to work, you must have a link from /proj/$USER/Barefoot
# to /proj/$USER/barefoot/perl_mod.  IOW, run this command from your
# /proj/$USER directory:
#
#		ln -s barefoot/perl_mod Barefoot
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

# if you want to test scripts with the -T switch, you're going to have issues.
# the problem is that cvs::WORKING_DIR is based on an environment variable
# ($USER), so it is inherently tainted.  thus, to make this work, we're going
# to need to untaint the personal CVS dir.  as we know the directories _we_
# added should only contain letters, we can safely assume that a valid
# cvs::WORKING_DIR would contain only slashes plus whatever a valid Linux
# username is (which is basically the same as \w).
BEGIN
{
	cvs::WORKING_DIR =~ m@^([/\w]+)$@;
	# use lib doesn't work here; do it by hand
	unshift @INC, $1 if $1;
}


$::debug_mode = 1;
$::debug = $::debug_mode;					# for backwards compatibility
# note: $debug is deprecated.  please use $debug_mode in all new code

1;


#
# Subroutines:
#


