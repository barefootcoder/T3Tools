#! /usr/local/bin/perl -w

# For CVS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# date
#
###########################################################################
#
# Some generally useful date routines
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package date;

### Private ###############################################################

use strict;

use Carp;
use Time::Local;

use Barefoot::base;
use Barefoot::array;
use Barefoot::string;


use enum qw(
	:PART_		SEC MIN HR DAY MON YR DOW DOY DST
);


our @DayName = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
		'Friday', 'Saturday');

our %DayNumbers =
(
	SUN		=>	0,
	MON		=>	1,
	TUE		=>	2,
	WED		=>	3,
	THU		=>	4,
	FRI		=>	5,
	SAT		=>	6,
);

our @MonAbbrev = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
		'Sep', 'Oct', 'Nov', 'Dec');

our %MonNumbers =
(
	JAN		=>	0,
	FEB		=>	1,
	MAR		=>	2,
	APR		=>	3,
	MAY		=>	4,
	JUN		=>	5,
	JUL		=>	6,
	AUG		=>	7,
	SEP		=>	8,
	OCT		=>	9,
	NOV		=>	10,
	DEC		=>	11,
);

our %Options =
(
	epoch		=>	'1/1/1980',
);


###########################
# Subroutines:
###########################


#
# import function
#

package Barefoot::date;
use Carp;
use Barefoot::base;

sub import
{
	my $class = shift;
	my (%opts) = @_;

	print STDERR "in import for date.pm\n" if DEBUG >= 5;
	foreach (keys %opts)
	{
		print STDERR "trying to set option $_\n" if DEBUG >= 4;
		if (exists $Options{$_})
		{
			$Options{$_} = $opts{$_};
		}
		else
		{
			croak("cannot set unknown option $_ in date module");
		}
	}
}

# back to "regular" package
package date;


###########################
# private "helper" routines
###########################


# parse a date in one of many formats:
# (month and day numbers may be only one digit instead of two)
#	mm/dd/yy
#	mm/dd/yyyy
#	dd/Mon/yy
#	dd/Mon/yyyy
#	mm-dd-yy
#	mm-dd-yyyy
#	dd-Mon-yy
#	dd-Mon-yyyy
#	yyyymmdd			(such as is returned by sortableString())
#	Mon dd yyyy
#	Mon dd yyyy 12:00AM	(such as is returned by Sybase)
# after parsing, you can get the month, day, and year, properly adjusted
# for timelocal() or timegm() (if used in an array context), or the result
# of timegm() with a time of midnight (if used in a scalar context)
# if you give it an invalid date, it will return undef or an empty list

sub _date_parse
{
	my ($date) = @_;
	croak("call to date routine with no date given") unless $date;
	my ($mon, $day, $year);

	# don't really care if this fails
	$date =~ s/ 12:00AM$//;

	if ($date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/)
	{
		$mon = $2 - 1;
		$day = $3;
		$year = $1;
	}
	elsif ($date =~ /^(...)  ?(\d?\d) (\d\d\d\d)$/)
	{
		return undef unless exists $MonNumbers{uc($1)};
		$mon = $MonNumbers{uc($1)};
		$day = $2;
		$year = $3;
	}
	else
	{
		($mon, $day, $year) = split(m</|->, $date);
		# if we don't get all three parts, might as well bail now
		return undef unless defined $mon and defined $day and defined $year;

		if ($day =~ /^[A-Z][a-z][a-z]$/)
		{
			# this must be dd/Mon/yyyy type format
			my $mon_abbrev = $day;
			$day = $mon;
			# this already returns zero-based for month
			$mon = $MonNumbers{uc($mon_abbrev)};
		}
		else
		{
			--$mon;							# timegm expects zero-based
		}
	}

	if ($year >= 100)
	{
		$year -= 1900;						# account for 2 or 4 digit years
	}
	elsif ($year <= 50)
	{
		$year += 100;						# nice if can say 01 for 2001
	}

	print STDERR "_date_parse: mon $mon, day $day, year $year\n" if DEBUG >= 2;

	# this will return undef if timegm vomits
	# we use timegm instead of timelocal to avoid problems with DST
	# if array context is requested, we return month, day, and year
	# so that the user can send it to timelocal if desired
	my $time_secs = eval { timegm(0,0,0,$day,$mon,$year) };
	return defined($time_secs)
		? (wantarray ? ($mon, $day, $year) : $time_secs)
		: (wantarray ? () : undef);
}


###########################
# public routines
###########################


# this one just tests for a valid date and returns 1 or 0
sub isValid
{
	my ($date) = @_;

	return defined(_date_parse($date));
}


sub mdy
{
	my ($day, $mon, $year) = (localtime $_[0])[3..5];
	$year += 1900, ++$mon;
	return "$mon/$day/$year";
}


sub today
{
	return mdy(time());
}


sub incDays
{
	my ($date, $inc) = @_;

	my $secs = _date_parse($date);
	print STDERR "seconds before increment: $secs\n" if DEBUG >= 3;
	$secs += ($inc * 24 * 60 * 60);		# increment seconds by that many days
	print STDERR "seconds after increment:  $secs\n" if DEBUG >= 3;

	my ($day, $mon, $year) = (gmtime $secs)[3..5];
	$year += 1900, ++$mon;
	print STDERR "incDays: new date is $mon/$day/$year\n" if DEBUG >= 2;

	return $year . string::lpad($mon, 2, 0) . string::lpad($day, 2, 0);
}


# this returns the difference in days between two dates (older date first)
# it will return undef if either date is invalid
# it will return a negative number if you put the newer date first
# if you send it only one date, it will return the difference between that
# date and today
sub dayDiff
{
	my ($old_date, $new_date) = @_;

	my $old_secs = _date_parse($old_date);
	# sortableString() is a shortcut for getting today's date
	# (probably not a very efficient one)
	my $new_secs = defined($new_date) ? _date_parse($new_date)
			: _date_parse(sortableString());
	return undef unless defined($old_secs) and defined($new_secs);

	my $diff_secs = $new_secs - $old_secs;
	# this should always return an int because the time values were built
	# (by _date_parse) with no hours, minutes, or seconds
	return $diff_secs / (24 * 60 * 60);
}


# this routine takes a date and an optional time, and returns the number
# of seconds since the epoch (same as time() does for the current time)
# date formats it understands are the same as _date_parse() (which see)
# time format is one of
#		hh:mm		(24-hour)
#		hh:mm:ss	(24-hour)
#		hh:mmXM		(12-hour)
#		hh:mm:ssXM	(12-hour)
#		hh.mm		(24-hour)
#		hh.mm.ss	(24-hour)
#		hh.mmXM		(12-hour)
#		hh.mm.ssXM	(12-hour)
# where XM is one of AM, PM, am, pm, A, P, a, or p
sub dateTimeSeconds
{
	my ($date, $time) = @_;
	$time = "0:0" unless $time;					# default time is midnight
	my $sep = '(?:\.|:)';						# time separator pattern
	my $ampm = '([AaPp])[mM]?';					# AM/PM marker

	my ($mon, $day, $year) = _date_parse($date);
	# print "mon $mon, day $day, year $year\n";
	if ( $year and $time =~ /^(\d+)$sep(\d+)(?:$sep(\d+))?(?:$ampm)?$/ )
	{
		my ($hours, $mins, $secs, $meridian) = ($1, $2, $3, $4);
		$secs = 0 unless $secs;
		$meridian = lc($meridian);				# for ease of comparison
		if ($hours == 12 and $meridian eq "a")	# midnight
		{
			$hours = 0;
		}
		elsif ($hours != 12)					# noon is same either way
		{
			$hours += 12 * ($meridian eq "p");	# add 12 if PM
		}

		# print "hour $hours, min $mins, sec $secs\n";
		return timelocal($secs, $mins, $hours, $day, $mon, $year);
	}
	else
	{
		# error
		return undef;
	}
}


sub sortableString
{
	my ($sep) = @_;

	$sep = "" if !defined($sep);		# separator for elements
	my $date = `date "+%Y$sep%m$sep%d"`;
	chomp $date;
	return $date;
}


sub MondayTime
{
	my $today = (gmtime(time))[PART_DOW];

	# if 0 (Sunday), use 6 days, else subtract 1 (Monday)
	# now num_days will be number of days ago the last Monday was
	my $num_days = $today == 0 ? 6 : $today - 1;

	return time - $num_days * 24 * 60 * 60;
}


sub MondayDate
{
	my $monday_time = MondayTime();
	my ($day, $mon, $year) = (gmtime $monday_time)[3..5];
	$mon += 1, $year += 1900;
	return "$mon/$day/$year";
}


###########################################################################
#
# the period functions
#
# #########################################################################
#

sub period_num
{
	my ($date, $period_len, $epoch) = @_;
	$epoch = $Options{epoch} unless defined $epoch;
	print STDERR "period_num: using epoch $epoch\n" if DEBUG >= 3;

	print STDERR "period_num: ",
			int(dayDiff($epoch, $date) / $period_len), "\n" if DEBUG >= 3;
	return int(dayDiff($epoch, $date) / $period_len);
}


sub period_name
{
	my ($period_num, $period_len, $epoch) = @_;
	$epoch = $Options{epoch} unless defined $epoch;
	print STDERR "period_num: using epoch $epoch\n" if DEBUG >= 3;

	my $start = incDays($epoch, $period_num * $period_len);
	my $end = incDays($start, $period_len - 1);

	return mdy($start) . " - " . mdy($end);
}


###########################
# Return a true value:
###########################

1;
