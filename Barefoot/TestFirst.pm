###########################################################################
#
# Barefoot::TestFirst
#
###########################################################################
#
# Routines to aid in test-first programming.  See _eXtreme Programming eXplained_ for a good discussion of
# test-first methods.
#
# Never use this module in production code!  It's only for test scripts, and may not be production safe.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2007 Barefoot Software
#
###########################################################################

package Barefoot::TestFirst;

### Private ###############################################################

use strict;
use warnings;

use base qw<Exporter>;
our @EXPORT = qw< verify_err run_proglet >;


use Carp;

use Barefoot;


die("Barefoot::TestFirst not designed to run in production code!") unless DEBUG;

# test scripts should demand that there be no errors
$SIG{__WARN__} = sub { die $_[0] };


###########################
# Subroutines:
###########################


sub verify_err (&$$)
{
	my ($code, $err, $msg) = @_;

	eval { &$code };
	if ($@)
	{
		croak("got incorrect error: $msg") unless $@ =~ /\Q$err\E/;
	}
	else
	{
		croak("didn't get expected error: $msg");
	}
}


sub run_proglet
{
	my ($return_what, $proglet) = @_;

	$proglet = 'use Barefoot(DEBUG => ' . DEBUG . ");\n" . $proglet;
	$proglet =~ s/'/'"'"'/g;											# funky quoting makes ' work for shell cmdline
	debuggit(4 => "proglet is", $proglet);

	if ($return_what eq 'EXITCODE')
	{
		my $exitcode = system("perl -e '$proglet'");
		return $exitcode == 0;
	}
	elsif ($return_what eq 'STDOUT')
	{
		my $out = `perl -e '$proglet'`;
		return $out;
	}
	elsif ($return_what eq 'STDERR')
	{
		my $out = `perl -e '$proglet' 2>&1 1>/dev/null`;
		return $out;
	}
	elsif ($return_what eq 'BOTH')
	{
		my $out = `perl -e '$proglet' 2>&1`;
		return $out;
	}

	die("dunno what $return_what means");
}


###########################
# Return a true value:
###########################

1;
