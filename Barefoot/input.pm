#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# Revision 1.1  1999/11/22 16:24:34  buddy
# Initial revision
#
#
# $Id$
# $Revision$

###########################################################################
#
# input
#
###########################################################################
#
# General routines to help with script input.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999 Barefoot Software.
#
###########################################################################

package Barefoot::input;

### Private ###############################################################

use strict;

use vars qw(@ISA @EXPORT_OK);
require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(get_yn input);

1;


#
# Subroutines:
#


sub get_yn
{
	my ($prompt) = @_;

	# prompt is optional
	print $prompt if defined $prompt;
	print "  [y/N] ";

	my $yn = <STDIN>;
	return 1 if $yn =~ /^y/i;
	return 0;
}

sub input
{
	my ($prompt, $default) = @_;

	local ($|) = 1;							# autoflush stdout
	print $prompt;
	print " (", $default, ")" if defined($default);
	print "  " if defined($prompt);

	my $answer = <STDIN>;
	chomp $answer;
	return $answer ? $answer : $default;
}
