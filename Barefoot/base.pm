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
# See Barefoot::debug for full details on DEBUG.
#
# Note that the same chicken-and-egg problem you have with testing
# Barefoot::debug applies to Barefoot::base as well; you can't get the
# version of base.pm from your CVS working directory as you can with other
# modules.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2001 Barefoot Software.
#
###########################################################################

package Barefoot::base;

### Private ###############################################################

use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(true false);


sub true();
sub false();


1;


#
# Subroutines:
#

sub import
{
	my $pkg = shift;

	# print STDERR "here i am in base import!\n";
	$pkg->export_to_level(1, $pkg, 'true');
	$pkg->export_to_level(1, $pkg, 'false');

	my $caller_package = caller;
	# print STDERR "my calling package is $caller_package\n";
	unless (defined eval "${caller_package}::DEBUG()")
	{
		my $main_debug_value = eval "main::DEBUG()";
		if (defined $main_debug_value)
		{
			# pass through DEBUG value from main package
			eval "sub ${caller_package}::DEBUG () "
					. "{ return $main_debug_value; }";
		}
		else
		{
			eval "sub ${caller_package}::DEBUG () { return 0; }";
		}
	}
}

sub true ()
{
	return 1;
}

sub false ()
{
	return 0;
}
