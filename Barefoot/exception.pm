###########################################################################
#
# exception
#
###########################################################################
#
# try / catch / rethrow
#
# Allows use of die() as an exception, as per the example in the perlsub manpage.  The only difference is that
# the die() message (i.e., $@) is first parsed out into message, file, and line.  The message itself is passed
# to catch as $_; the file and line are made available as $__FILE__ and $__LINE__, respectively (this is
# similar to the C/C++ macros).
#
# Be careful not to confuse __LINE__ with $__LINE__.  __LINE__ will report the current source line number.
# $__LINE__ will report the line number of the last exception (i.e., die()) within a try block.
#
# The rethrow command will pass on the (presumably uncaught) exception, maintaining the original file and line
# number info.  You could use die() with no arguments, but that tacks on additional file and line number info
# and confuses the try block's exception parser.
#
#		try
#		{
#			some_func();
#		}
#		catch
#		{
#			# use return to exit the catch handler
#			make_more_memory() and return if /out of memory/;
#			return if /timeout/;										# this is okay (no error)
#			rethrow;													# ran out of ideas
#		};
#
# Don't forget the ending semi-colon after your catch block; that is mandatory.  Also notice that a catch
# block is actually an anonymous subroutine and NOT an actual block; thus you must use "return" and not
# "last".
#
#
# timeout
#
# Allows execution of code which may stall, specifying a number of seconds after which the attempt will be
# terminated.  Returns true if the code executed successfully (i.e., the timeout was not reached; this does
# not necessarily mean that the code _worked_) or false if it was interrupted.
#
# As a special case, a timeout value of 0 causes no interruption to be performed (i.e., if the code stalls, it
# just hangs forever).  This allows a variable to be passed which may be a timeout or 0 for no timeout.
#
#		my $success = timeout
#		{
#			while (1)													# keep trying "forever"
#			{
#				open(FILE, "somefile");									# (some other process makes this file)
#				sleep 1;												# (don't max the CPU!)
#			}
#		} 30;															# but really only try for 30 seconds
#		die("somefile never appeared") unless $success;
#		my $input = <FILE>;												# we're pretty sure it opened okay
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2000-2007 Barefoot Software
#
###########################################################################

package Barefoot::exception;

### Private ###############################################################

use strict;
use warnings;

use base qw(Exporter);
use vars qw(@EXPORT $__FILE__ $__LINE__ $__CATCH__);
@EXPORT = qw(try catch rethrow timeout $__FILE__ $__LINE__);

use Carp;

use Barefoot;


sub try(&@);
sub catch(&);
sub rethrow();
sub timeout(&$);

$__CATCH__ = 0;


###########################
# Subroutines:
###########################


sub try (&@)
{
	my ($try, $catch) = @_;

	debuggit(5 => "exception.pm: in try block");
	eval { &$try };
	if ($@)
	{
		# print "in try: $@";
		$@ =~ /^(.*) at (.*) line (\d+)(?:.*\.)?\n$/s;
		die("incorrect 'die' format: $@") unless $3;
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
			debuggit(4 => "$0 ($$): exception is >>", $_, "<<");
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


###########################
# Return a true value:
###########################

1;
