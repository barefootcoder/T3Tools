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
# A few subs, which allows you to actually _use_ Perl formats:
#
#	my $formatted = swrite(MY_FORMAT, @stuff);
#	# swrite() treats its first argument as a Perl-style format
#	# all other args are expected to be the variables defined in the format
#	# it returns a formatted string
#
#	writeln(MY_FORMAT, @stuff);
#	# writeln() treats its first argument as a Perl-style format
#	# all other args are expected to be the variables defined in the format
#	# first, writeln() will append $\ (or \n by default) to MY_FORMAT,
#	#	unless it is already there
#	# then writeln() prints the formatted string to the currently selected
#	#	filehandle (STDOUT by default)
#
# Also, a sub which allows you deal with double-quoted, comma-separated
# values (commonly referred to as CSV) just as you would a normal split:
#
#	my @fields = CSV::split($expr);
#	# /PATTERN/ not needed; always assumed to be , (with double-quoting)
#	# LIMIT always assumed to be -1 (i.e., trailing null fields not stripped)
#	# if EXPR ($expr) is omitted, will split $_
#	# can return undef if (e.g.) double quotes don't match
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

use Text::CSV;

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


package CSV;

sub split
{
	my ($expr) = @_;
	$expr = $_ unless defined $expr;

	my $csv = Text::CSV->new();
	return undef unless $csv->parse($expr);
	return $csv->fields();
}
