#! /usr/local/bin/perl

# For CVS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::Server
#
###########################################################################
#
# Constants and subroutines needed by the T3 server.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2001-2002 Barefoot Software.
#
###########################################################################

package T3::Server;

### Private ###############################################################

use strict;

use Barefoot::config_file;
use Barefoot::T3::base;


use constant TEST_MODULES_DIR => './test_modules';


our $cfg_file = config_file->read(T3::CONFIG_FILE);
our $workgroup = defined($ENV{T3_WORKGROUP})
		? $ENV{T3_WORKGROUP} : T3::DEFAULT_WORKGROUP;

our %modules;


1;


#
# Subroutines:
#

sub config_param
{
	my $group = $workgroup;
	my $directive;
	if (@_ > 1)
	{
		($group, $directive) = @_;
	}
	else
	{
		($directive) = @_;
	}

	return $cfg_file->lookup($group, $directive);
}

sub register_request
{
	die("attempt to register module which is already registered [$_[0]]")
			if exists $modules{$_[0]};
	$modules{$_[0]} = $_[1];
}

sub exists_request
{
	return exists $modules{$_[0]};
}

sub execute_request
{
	$modules{$_[0]}->(@_[1..$#_]);
}
