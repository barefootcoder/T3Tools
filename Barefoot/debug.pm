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
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2000-2006 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
#
###########################################################################

package Barefoot::debug;

### Private ###############################################################

use strict;
use warnings;

use Carp;

use Barefoot::cvsdir;

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


###########################
# Subroutines:
###########################


sub import
{
	my $pkg = shift;
	my $debug_value = shift;
	# print STDERR "here i am in debug import with value ";
	# print defined $debug_value ? $debug_value : "undefined", "\n";

	my $caller_package = caller;
	# print STDERR "my calling package is $caller_package\n";
	croak("DEBUG already defined; make use statement earlier in code")
			if defined eval "${caller_package}::DEBUG();";

	$debug_value = 0 unless defined $debug_value;
	eval "sub ${caller_package}::DEBUG () { return $debug_value; }";

	# also have to tuck this value into the Barefoot namespace
	# this will serve as the master value
	# (sort of like main:: but it'll work under mod_perl too)
	# NOTE: it is possible for there to already be a value here; that means
	# that this is changing the debug value for a module or other sub-script
	# after it has already been set in the main script.  this is perfectly
	# acceptable (and in fact desireable sometimes), so check for it first.
	my $master_debug = eval "Barefoot::DEBUG();";
	# print STDERR "eval returns $master_debug and eval err is $@\n";
	eval "sub Barefoot::DEBUG () { return $debug_value; }"
			unless defined $master_debug;
}


###########################
# Return a true value:
###########################

1;
