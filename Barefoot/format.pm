#! /usr/local/bin/perl

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# format
#
###########################################################################
#
# The swrite() sub, which allows you to actually _use_ Perl formats.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2000 Barefoot Software.
#
###########################################################################

package Barefoot::format;

### Private ###############################################################

use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
@EXPORT = qw(swrite writeln);

sub swrite;
sub writeln;

1;


#
# Subroutines:
#


sub swrite
{
	my ($format, @vars) = @_;
	$^A = "";
	formline($format, @vars);
	return $^A;
}

sub writeln
{
	my ($format, @vars) = @_;
	my $terminator = $\ ? $\ : "\n";
	$format .= $terminator unless $format =~ /$terminator\Z/;
	$^A = "";
	formline($format, @vars);
	print $^A;
}
