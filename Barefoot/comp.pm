#! /usr/local/bin/perl

###########################################################################
#
# comp
#
###########################################################################
#
# max, min, range, that sort of stuff
#
###########################################################################

package comp;

### Private ###############################################################

use strict;

1;


#
# Subroutines:
#


sub max
{
	my ($a, $b) = @_;

	return $a > $b ? $a : $b;
}

sub min
{
	my ($a, $b) = @_;

	return $a < $b ? $a : $b;
}

sub range
{
	my ($num, $bottom, $top) = @_;

	return $num > $top ? $top : ($num < $bottom ? $bottom : $num);
}
