#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# Revision 1.3  2001/08/05 02:24:39  buddy
# moved stuff from comp.pm (in order to phase out that module)
# changed min and max to be able to handle lists of arbitrary length
#
# Revision 1.2  2000/08/28 21:06:18  buddy
# first truly working version
#
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
#		range::min(@list);					# minimum number in list
#		range::max(@list);					# maximum number in list
#		range::force($num, $low, $high);	# force num between high and low
#		range::round($x, ROUND_UP);			# round number
#		range::round($x, ROUND_OFF, .5);	# round number to arbitrary base
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


# min function ... returns smallest number in list or undef for empty list
sub min
{
	return undef unless @_;

	my $min = shift @_;
	$_ < $min ? ($min = $_) : 0 foreach @_;
	return $min;
}

# max function ... ditto
sub max
{
	return undef unless @_;

	my $max = shift @_;
	$_ > $max ? ($max = $_) : 0 foreach @_;
	return $max;
}


# force into a certain range
sub force
{
	my ($num, $low, $high) = @_;

	return $num > $high ? $high : ($num < $low ? $low : $num);
}


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
