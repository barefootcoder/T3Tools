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

print STDERR "Barefoot::comp: this module is depracated; "
		. "use Barefoot::range instead\n";

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
