#! /usr/local/bin/perl -w

# For CVS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::Timer
#
###########################################################################
#
# Some general functions that are specific to the Timer module.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package Barefoot::T3::Timer;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw<calc_time calc_date>;

use Barefoot::base;
use Barefoot::range;


###########################
# Subroutines:
###########################


# ------------------------------------------------------------
# Calculation Procedures
# ------------------------------------------------------------


sub calc_time
{
	my ($line) = @_;
	my @times = split(',', $line);
	my $total_time = 0;

	my $current_time = false;
	foreach my $time (@times)
	{
		if ($time =~ /^([+-]\d+)$/)
		{
			$total_time += $1 * 60;
			next;
		}

		my ($divisor, $from, $to) = $time =~ m{(?:(\d+)/)?(\d+)-(\d+)?};
		die("illegal format in time file") unless $from;
		if (!$to)
		{
			die("more than one current time in time file") if $current_time;
			$current_time = true;
			$to = time;
		}
		$total_time += ($to - $from) / ($divisor ? $divisor : 1);
	}
	return range::round($total_time / 60, range::ROUND_UP);
}


sub calc_date
{
	my ($line) = @_;

	my $seconds;
	if ($line and $line =~ /(\d+),$/)	# ends in a comma, must be paused
	{
		$seconds = $1;
	}
	else								# current or no time given
	{
		$seconds = time;
	}

	# adjust for working after midnight ... if the time is before 6am,
	# we'll just subtract a day
	my ($hour) = (localtime $seconds)[2];
	$seconds -= 24*60*60 if $hour < 6;

	my ($day, $mon, $year) = (localtime $seconds)[3..5];
	return ++$mon . "/" . $day . "/" . ($year + 1900);
}


###########################
# Return a true value:
###########################

1;
