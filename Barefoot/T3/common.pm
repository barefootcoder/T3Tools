#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::common
#
###########################################################################
#
# Common constants and routines for all T3 modules.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package T3;

### Private ###############################################################

use strict;

use Barefoot::config_file;


use constant CONFIG_FILE => '/etc/t3.conf';
use constant DEFAULT_WORKGROUP => 'Barefoot';
use constant REQUEST_FILE => 't3.request';
use constant OUTPUT_FILE => 't3.output.';


our $cfg_file = config_file->read(CONFIG_FILE);
our $workgroup = defined($ENV{T3_WORKGROUP})
		? $ENV{T3_WORKGROUP} : DEFAULT_WORKGROUP;

our %modules;


1;


#
# Subroutines:
#


sub debug
{
	if (main::DEBUG)
	{
		my $level = 2;							# default in case not specified
		my $msg;
		if (@_ > 1)
		{
			($level, $msg) = @_;
		}
		else
		{
			($msg) = @_;
		}

		print STDERR "$0: $msg at ", scalar(localtime(time())), "\n"
				if main::DEBUG >= $level;
	}
}

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

sub register_module
{
	$modules{$_[0]} = $_[1];
}

sub exists_module
{
	return exists $modules{$_[0]};
}

sub execute_module
{
	$modules{$_[0]}->();
}
