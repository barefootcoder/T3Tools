#! /usr/local/bin/perl

###########################################################################
#
# date
#
###########################################################################
#
# Some generally useful date routines
#
###########################################################################

package date;

### Private ###############################################################

use strict;

use Time::Local;

use Barefoot::array;
use Barefoot::string;


use enum qw(
	:PART_		SEC MIN HR DAY MON YR DOW DOY DST
);

use vars qw(@DAY_NAME @MON_ABBREV);
@DAY_NAME = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
		'Friday', 'Saturday');
@MON_ABBREV = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
		'Sep', 'Oct', 'Nov', 'Dec');


1;


#
# Subroutines:
#


#
# private "helper" routines
#


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
#	yyyymmdd			(such as is returned by sortableString()
# after parsing, you can get the month, day, and year, properly adjusted
# for timelocal() or timegm() (if used in an array context), or the result
# of timegm() with a time of midnight (if used in a scalar context)
# if you give it an invalid date, it will return undef or an empty list
sub _date_parse
{
	my ($date) = @_;
	my ($mon, $day, $year);

	if ($date =~ /^(\d\d\d\d)(\d\d)(\d\d)$/)
	{
		$mon = $2;
		$day = $3;
		$year = $1;
	}
	else
	{
		($mon, $day, $year) = split(?/|-?, $date);
		if ($day =~ /^[A-Z][a-z][a-z]$/)
		{
			# this must be dd/Mon/yyyy type format
			my $mon_abbrev = $day;
			$day = $mon;
			# aindex already returns zero-based for month
			$mon = aindex(@MON_ABBREV, $mon_abbrev);
		}
		else
		{
			--$mon;							# timegm expects zero-based
		}
	}

	$year -= 1900 if $year >= 100;			# account for 2 or 4 digit years;

	# this will return undef if timegm vomits
	# we use timegm instead of timelocal to avoid problems with DST
	# if array context is requested, we return month, day, and year
	# so that the user can send it to timelocal if desired
	my $time_secs = eval { timegm(0,0,0,$day,$mon,$year) };
	return defined($time_secs)
		? (wantarray ? ($mon, $day, $year) : $time_secs)
		: (wantarray ? () : undef);
}


#
# public routines
#


# this one just tests for a valid date and returns 1 or 0
sub isValid
{
	my ($date) = @_;

	return defined(_date_parse($date));
}

sub incDays
{
	my ($date, $inc) = @_;

	my $secs = _date_parse($date);
	$secs += ($inc * 24 * 60 * 60);		# increment seconds by that many days

	my ($day, $mon, $year) = (localtime $secs)[3..5];
	$year += 1900, ++$mon;

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
	my $today = (localtime(time))[PART_DOW];

	# if 0 (Sunday), use 6 days, else subtract 1 (Monday)
	# now num_days will be number of days ago the last Monday was
	my $num_days = $today == 0 ? 6 : $today - 1;

	return time - $num_days * 24 * 60 * 60;
}

sub MondayDate
{
	my $monday_time = MondayTime();
	my ($day, $mon, $year) = (localtime $monday_time)[3..5];
	$mon += 1, $year += 1900;
	return "$mon/$day/$year";
}
