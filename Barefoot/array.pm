#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# array
#
###########################################################################
#
# This adds some useful (and surprising that they haven't been defined yet)
# functions for arrays.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999 Barefoot Software.
#
###########################################################################

package Barefoot::array;

### Private ###############################################################

use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(in aindex);


sub in (\@$;$);
sub aindex (\@$;$$);

use constant	STRING	=>		's';
use constant	INT		=>		1;

1;


#
# Subroutines:
#

# internal helper routine

sub _compare
{
	my ($lhs, $rhs, $type) = @_;
	{
		no warnings qw<numeric>;
		$type = ($lhs + 0 eq $lhs) ? INT : STRING unless defined($type);
	}

	if ($type eq STRING)
	{
		return $lhs eq $rhs;
	}
	elsif ($type eq INT)
	{
		return $lhs == $rhs;
	}
	elsif ($type =~ /.0*1$/)
	{
		return $lhs / $type == $rhs / $type;
	}
	else
	{
		die("illegal comparison type in array.pm");
	}
}


sub in (\@$;$)
{
	my ($array, $element, $type) = @_;

	foreach my $item (@$array)
	{
		return 1 if _compare($item, $element, $type);
	}
	return 0;
}

sub aindex (\@$;$$)
{
	my ($array, $element, $type, $pos) = @_;
	$pos = $[ unless defined $pos;

	for (my $x = $pos; $x <= $#{$array}; $x++)
	{
		# print "checking element $x ...\n";
		return $x if _compare($array->[$x], $element, $type);
	}
	# print "didn't find it :-(\n";
	return $[ - 1;
}
