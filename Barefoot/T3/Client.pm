#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::Client
#
###########################################################################
#
# Routines necessary for any client program to communicate with the T3
# server.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package T3::Client;

### Private ###############################################################

use strict;

use Barefoot::exception;
use Barefoot::T3::common;


our %output_pipes;

# make sure output pipes get cleaned up at end of program
END
{
	foreach my $pipe_file (keys %output_pipes)
	{
		unlink $pipe_file if -e $pipe_file;
	}
}


1;


#
# Subroutines:
#


sub send_request
{
	T3::debug(2, "about to open pipe");
	open(PIPE, ">" . T3::REQUEST_FILE)
			or die("can't open request pipe for writing");
	T3::debug(2, "opened pipe");
	print PIPE @_, "\n";
	T3::debug(2, "printed to pipe");
	close(PIPE);
	T3::debug(2, "closed pipe");
}

sub retrieve_output
{
	my ($id) = @_;

	my $pipe_file = T3::OUTPUT_FILE . $id;
	my $pipe_is_there = timeout
	{
		until (-p $pipe_file)
		{
			die("output file $pipe_file isn't a pipe") if -e _;
			sleep 1;
		}
	} 20;
	die("server never created output pipe $pipe_file") unless $pipe_is_there;

	# make sure this pipe will get cleaned up when we exit
	$output_pipes{$pipe_file} = "";		# value isn't used

	my ($success, @output);
	T3::debug(2, "began trying to get output");
	for (1..10)							# give it a few tries ...
	{
		$success = timeout
		{
			open(PIPE, $pipe_file)
					or die("can't open output pipe for reading");
			@output = <PIPE>;
		} 3;
		T3::debug(2, "read output") if $success;
		die("never got EOF from output pipe") if @output and not $success;
		last if $success and @output;
	}
	T3::debug(2, "gave up trying to get output");
	die("can't seem to get any output from $pipe_file")
			unless $success and @output;
	close(PIPE);
	# unlink($pipe_file);
	# print STDERR "got ", scalar(@output), " lines of output\n";
	return @output;
}
