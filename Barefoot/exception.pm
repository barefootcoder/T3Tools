#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# exception
#
###########################################################################
#
# try / catch / rethrow
#
# Allows use of die() as an exception, as per the example in the perlsub
# manpage.  The only difference is that the die() message (i.e., $@) is
# first parsed out into message, file, and line.  The message itself is
# passed to catch as $_; the file and line are made available as $__FILE__
# and $__LINE__, respectively (this is similar to the C/C++ macros).
#
# Be careful not to confuse __LINE__ with $__LINE__.  __LINE__ will report
# the current source line number.  $__LINE__ will report the line number of
# the last exception (i.e., die()) within a try block.
#
# The rethrow command will pass on the (presumably uncaught) exception,
# maintaining the original file and line number info.  You could use die()
# with no arguments, but that tacks on additional file and line number info
# and confuses the try block's exception parser.
#
#		EXAMPLE:
#
#	try
#	{
#		some_func();
#	}
#	catch
#	{
#		# use return to exit the catch handler
#		make_more_memory() and return if /out of memory/;
#		return if /timeout/;					# this is okay (no error)
#		rethrow;								# ran out of ideas
#	}
#
#
# timeout
#
# Allows execution of code which may stall, specifying a number of seconds
# after which the attempt will be terminated.  Returns true if the code
# executed successfully (i.e., the timeout was not reached; this does not
# necessarily mean that the code _worked_) or false if it was interrupted.
#
# As a special case, a timeout value of 0 causes no interruption to be
# performed (i.e., if the code stalls, it just hangs forever).  This allows
# a variable to be passed which may be a timeout or 0 for no timeout.
#
#		EXAMPLE:
#
#	my $success = timeout
#	{
#		while (1)						# keep trying "forever"
#		{
#			open(FILE, "somefile");		# (some other process makes this file)
#			sleep 1;					# (don't max the CPU!)
#		}
#	} 30;								# but really only try for 30 seconds
#	die("somefile never appeared") unless $success;
#	my $input = <FILE>;					# we're pretty sure it opened okay
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package Barefoot::exception;

### Private ###############################################################

use strict;

use base qw(Exporter);
use vars qw(@EXPORT $__FILE__ $__LINE__ $__CATCH__);
@EXPORT = qw(try catch rethrow timeout $__FILE__ $__LINE__);

use Carp;


sub try(&@);
sub catch(&);
sub rethrow();
sub timeout(&$);

$__CATCH__ = 0;

1;


#
# Subroutines:
#


sub try (&@)
{
	my ($try, $catch) = @_;

	# print STDERR "in try block\n";
	eval { &$try };
	if ($@)
	{
		# print "in try: $@";
		$@ =~ /^(.*) at (.*) line (\d+)(?:.*\.)?\n$/;
		die("incorrect 'die' format") unless $3;
		local $_ = $1;
		$__FILE__ = $2;
		$__LINE__ = $3;
		$__CATCH__ = 1;
		&$catch;
		$__CATCH__ = 0;
	}
}

sub catch (&)
{
	$_[0];
}

sub rethrow ()
{
	croak("rethrow outside catch block") unless $__CATCH__;
	die("$_ at $__FILE__ line $__LINE__\n");
}

sub timeout (&$)
{
	my ($code, $seconds) = @_;

	if ($seconds)
	{
		my $timed_out = 0;
		try
		{
			local $SIG{ALRM} = sub { die("timeout"); };
			alarm $seconds;
			&$code;
			alarm 0;
		}
		catch
		{
			# print STDERR "exception is >>$_<<\n";
			if ( /^timeout$/ )
			{
				$timed_out = 1;
				return;
			}
			rethrow;					# some other exception; rethrow
		};
		return not $timed_out;			# _not_ timing out indicates success
	}
	else
	{
		&$code;
	}
}
