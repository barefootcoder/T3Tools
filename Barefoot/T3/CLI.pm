###########################################################################
#
# Barefoot::T3::CLI
#
###########################################################################
#
# This module provides some helper functions for the CLI versions of T3 apps.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2006-2007 Barefoot Software, Copyright (c) 2006-2007 ThinkGeek
#
###########################################################################

package Barefoot::T3::CLI;

### Private ###############################################################

use strict;
use warnings;

use Barefoot;

use base qw<Exporter>;
our @EXPORT = qw< cli_common_opts cli_get_command cli_fatal >;


#################################
# SUBROUTINES
#################################

sub cli_common_opts
{
	my ($parminfo, $opts) = @_;

	$parminfo->{'force'} = defined $opts->{'f'};
	$parminfo->{'noconfirm'} = defined $opts->{'f'};
	$parminfo->{'user'} = $opts->{'u'};
	$parminfo->{'client'} = uc($opts->{'C'});
	$parminfo->{'project'} = uc($opts->{'P'});
	$parminfo->{'phase'} = uc($opts->{'H'});
	$parminfo->{'tracking'} = uc($opts->{'T'});
}


sub cli_get_command
{
	my ($funcs, $opts) = @_;

	my $command;
	foreach my $copt (keys %$funcs)
	{
		if (exists $opts->{$copt})
		{
			cli_fatal(2, "you must specify exactly one command (", join(',', keys %$funcs), ")") if defined $command;
			$command = $funcs->{$copt};
			debuggit(2 => "defined command as", $command);
		}
	}

	return $command;
}


sub cli_fatal
{
	my ($exitcode, @messages) = @_;
	my $progname = $0;
	$progname =~ s@.*/@@;

	print STDERR "$progname: ", @messages, "\n";
	exit $exitcode;
}
