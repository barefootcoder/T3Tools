#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# Revision 1.1  2000/02/03 16:02:21  buddy
# Initial revision
#
#
# $Id$
# $Revision$

###########################################################################
#
# range
#
###########################################################################
#
# This module contains useful functions relating to ranges of numbers.
# The functions contained herein are:
#
#		round($x, ROUND_UP);			# round number
#		round($x, ROUND_OFF, .5);		# round number to an arbitrary base
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999 Barefoot Software.
#
###########################################################################

package range;

### Private ###############################################################

use strict;

use Barefoot::array;


# constants for round()
use constant ROUND_OFF => 'O';
use constant ROUND_UP => 'U';
use constant ROUND_DOWN => 'D';
my @_rounding_types = (ROUND_OFF, ROUND_UP, ROUND_DOWN);


1;


#
# Subroutines:
#


# rounding function ... note that if $whichway is not specified, it will
# be interpreted as OFF ... $towhat defaults to 1 (naturally)
sub round
{
	my ($number, $whichway, $towhat) = @_;
	$whichway = ROUND_OFF if !defined $whichway;
	$towhat = 1 if !$towhat;

	die("illegal rounding type") unless in @_rounding_types, $whichway;

	$number /= $towhat;
	if ($number =~ /\.(\d)/)
	{
		$number = int $number;
		++$number if $whichway eq ROUND_UP;
		++$number if $whichway eq ROUND_OFF && $1 >= 5;
	}
	return $number * $towhat;
}
