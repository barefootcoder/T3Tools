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
# This module also sets the DEBUG constant, so that you can use tests like:
#
#		print "debugging message" if DEBUG;
#
# Since this is a compile-time constant, such code will be excised entirely
# during compilation if this module is not use'd.  Thus, it will not slow
# down run-time execution.  However, DEBUG itself will not be defined unless
# Barefoot::base is also use'd, so be sure that it is.  You must also make
# sure that Barefoot::debug is use'd _before_ Barefoot::base; in general,
# it is recommended that you put your "use Barefoot::debug" statement very
# early in your script.
#
# See also: Barefoot::base and Barefoot::debug_verbose
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2001 Barefoot Software.
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


use Barefoot::base;


1;


#
# Subroutines:
#


sub import
{
	my $pkg = shift;
	my $debug_value = shift;
	# print STDERR "here i am in debug import with value ";
	# print defined $debug_value ? $debug_value : "undefined", "\n";

	my $caller_package = caller;
	# print STDERR "my calling package is $caller_package\n";
	die("DEBUG already defined; make use statement earlier in code")
			if defined eval "${caller_package}::DEBUG();";

	$debug_value = 1 unless defined $debug_value;
	eval "sub ${caller_package}::DEBUG () { return $debug_value; }";
}
