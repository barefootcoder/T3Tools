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

use Barefoot::string;


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
#	mm-dd-yy
#	mm-dd-yyyy
#	yyyymmdd			(such as is returned by sortableString()
# after parsing, it tosses it off to timelocal and returns the time value
# if you give it an invalid date, it will return undef
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
	}

	--$mon;									# timelocal expects this
	$year -= 1900 if $year >= 100;			# account for 2 or 4 digit years;

	# this will return undef if timegm vomits
	# we use timegm instead of timelocal to avoid problems with DST
	return eval { timegm(0,0,0,$day,$mon,$year) };
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

sub sortableString
{
	my ($sep) = @_;

	$sep = "" if !defined($sep);		# separator for elements
	my $date = `date "+%Y$sep%m$sep%d"`;
	chomp $date;
	return $date;
}

sub MondayDate
{
	my $today = (localtime(time))[6];

	# if 0 (Sunday), use 6 days, else subtract 1 (Monday)
	# now num_days will be number of days ago the last Monday was
	my $num_days = $today == 0 ? 6 : $today - 1;

	my $monday_time = time - $num_days * 24 * 60 * 60;
	my ($day, $mon, $year) = (localtime $monday_time)[3..5];
	$mon += 1, $year += 1900;
	return "$mon/$day/$year";
}
