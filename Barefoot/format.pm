#! /usr/local/bin/perl

# For CVS:
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
# licensing agreement.  Copyright (c) 2000-2002 Barefoot Software.
#
###########################################################################

package Barefoot::format;

### Private ###############################################################

use strict;

use Text::CSV;
use Date::Format;
use Data::Dumper;

use Barefoot::base;


use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<swrite writeln>;

sub swrite;
sub writeln;

# hash to correspond our date formats with those understood by Date::Format
our %date_fmt =
(
	'@m'	=>	'%L',
	'@d'	=>	'%e',
	'@y'	=>	'%y',
	'@yyy'	=>	'%Y',
	'@ww'	=>	'%a',
	'#m'	=>	'%m',
	'#d'	=>	'%d',
);


#
# Subroutines:
#


# can't make these true constants or else we can't interpolate with them
our $STD_FMT = '[@^][<>|]*';
our $NUM_FMT = '[@^]\#*\.\#*';
our $DATE_FMT_PART = '[@\#][mdywHMS]+';
our $DATE_FMT = $DATE_FMT_PART . '.*?(?=\s|$)';

sub swrite
{
	my ($format, @vars) = @_;

	# clear accumulator
	$^A = "";

	# break up the format into pieces
	my @pieces = split( / ( $DATE_FMT | $NUM_FMT | $STD_FMT ) /x, $format, -1);
	print STDERR Dumper(\@pieces) if DEBUG >= 4;

	# substitute time/date stuff
	my $pos = 0;
	foreach (@pieces)
	{
		if ( / ^ $STD_FMT $ /x )
		{
			# nothing special to do, standard Perl format will take care of it

			# skip to next variable
			++$pos;
		}
		elsif ( / ^ $NUM_FMT $ /x )
		{
			# nothing special to do, standard Perl format will take care of it

			# skip to next variable
			++$pos;
		}
		elsif ( / ^ $DATE_FMT $ /x )
		{
			# substitute the various pieces with specs understood
			# by Date::Format, these are stored in the %date_fmt hash
			my $format = $_;
			$format =~ s/($DATE_FMT_PART)/$date_fmt{$1}/eg;
			print STDERR "translated $_ into $format\n" if DEBUG >= 2;

			# now put a generic format in the format string and
			# the results of Date::Format in the variable list
			$_ = '@' . '>' x (length($_) - 1);
			$vars[$pos] = time2str($format, $vars[$pos]);

			# skip to next variable
			++$pos;
		}
	}

	formline(join('', @pieces), @vars);
	return $^A;
}

sub writeln
{
	my $format = shift;
	my $terminator = $\ ? $\ : "\n";
	$format .= $terminator unless $format =~ /$terminator\Z/;
	print swrite($format, @_);
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


###########################
# Return a true value:
###########################

1;
