#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# debug_verbose
#
###########################################################################
#
# This module works exactly like Barefoot::debug (q.v.) except that it
# defines the DEBUG constant as 2 instead of 1.  This allows for two levels
# of debugging verbosity:
#
#		print "top-level debugging message" if DEBUG;
#		print "detailed debugging message" if DEBUG > 1;
#
# See Barefoot::debug for full details.
#
# Much of the code herein is directly copied from Barefoot::debug.  This
# is due to the difficulty of handling compile-time constants in a conditional
# manner.  Brilliant ideas on a solution for this will be welcomed.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2001 Barefoot Software.
#
###########################################################################

package Barefoot::debug_verbose;

### Private ###############################################################

use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(DEBUG);

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


sub DEBUG ()
{
	return 2;
}

use Barefoot::base;


1;


#
# Subroutines:
#


sub import
{
	my $pkg = shift;
	# print STDERR "here i am in debug_verbose import!\n";

	my $caller_package = caller;
	# print STDERR "my calling package is $caller_package\n";
	die("DEBUG already defined; make use statement earlier in code")
			if defined eval "${caller_package}::DEBUG();";
	$pkg->export_to_level(1, $pkg, 'DEBUG');
}
