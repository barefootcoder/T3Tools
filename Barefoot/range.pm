###########################################################################
#
# Barefoot::range
#
###########################################################################
#
# This module contains useful functions relating to ranges of numbers.  The functions contained herein are:
#
#		range::min(@list);												# minimum number in list
#		range::max(@list);												# maximum number in list
#		range::force($num, $low, $high);								# force num between high and low
#		range::round($x, range::ROUND_UP);								# round number
#		range::round($x, range::ROUND_OFF, .5);							# round number to arbitrary base
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 1999-2007 Barefoot Software
#
###########################################################################

package range;

### Private ###############################################################

use strict;
use warnings;

use Carp;

use Barefoot;


# constants for round()
use constant ROUND_OFF => 'O';
use constant ROUND_UP => 'U';
use constant ROUND_DOWN => 'D';
# note that you can't use => below, as it turns the constants into identifiers
my %_rounding_types = (ROUND_OFF, 1, ROUND_UP, 1, ROUND_DOWN, 1);


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


# rounding function ... note that if $whichway is not specified, it will be interpreted as OFF ... $towhat
# defaults to 1 (naturally)
sub round
{
	my ($number, $whichway, $towhat) = @_;
	$whichway = ROUND_OFF unless defined $whichway;
	$towhat = 1 unless $towhat;
	debuggit(3 => "round: rounding", $number, $whichway, "to nearest", $towhat);

	croak("illegal rounding type") unless exists $_rounding_types{$whichway};

	$number /= $towhat;
	if ($number =~ /\.(\d)/)
	{
		$number = int $number;
		++$number if $whichway eq ROUND_UP;
		++$number if $whichway eq ROUND_OFF && $1 >= 5;
	}
	return $number * $towhat;
}


###########################
# Return a true value:
###########################

1;
