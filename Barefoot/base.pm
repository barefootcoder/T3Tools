#! /usr/local/bin/perl

# For CVS:
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
# licensing agreement.  Copyright (c) 2001-2002 Barefoot Software.
#
###########################################################################

package Barefoot::base;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<true false>;


=comment
use Filter::Simple;

FILTER_ONLY
	code	=>	sub
				{
					print STDERR;
					s/
						\%\% DEBUG \s* \( (.*?) \) \s* ;
					/
						print STDERR $1, "\n" if DEBUG >= 2;
					/gx;
					print STDERR;
				};
=cut


sub true();
sub false();


###########################
# Subroutines:
###########################

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
		my $master_debug_value = eval "Barefoot::DEBUG()";
		if (defined $master_debug_value)
		{
			# print STDERR "passing through value $master_debug_value\n";
			# pass through DEBUG value from Barefoot package
			eval "sub ${caller_package}::DEBUG () "
					. "{ return $master_debug_value; }";
		}
		else
		{
			eval "sub ${caller_package}::DEBUG () { return 0; }";
			# better put this master area so won't be not found next time
			eval "sub Barefoot::DEBUG () { return 0; }";
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


###########################
# Return a true value:
###########################

1;
