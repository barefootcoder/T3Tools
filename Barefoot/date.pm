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
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 1999-2007 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
#
###########################################################################

package date;

### Private ###############################################################

use strict;
use warnings;

use Carp;
use Time::Local;
use Date::Parse;
use Date::Format;

use Barefoot;
use Barefoot::array;
use Barefoot::string;


use enum qw< :PART_		SEC MIN HR DAY MON YR DOW DOY DST >;


our @DayName = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');

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

our @MonAbbrev = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

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
	def_fmt		=>	'%Y-%m-%d',
	def_tfmt	=>	'%Y-%m-%d %T',
	epoch		=>	'1/1/1980',

	overriden	=>	{},
);


###########################
# Subroutines:
###########################


###########################
# private "helper" routines
###########################


sub _cvt_date_if_necessary
{
	my ($date) = @_;

	if ($date =~ /^\d{9,10}$/)
	{
		# already epoch seconds; no need to convert
		return $date;
	}

	# else just use str2time
	return str2time($date);
}


###########################
# public routines
###########################


# this one just tests for a valid date and returns 1 or 0
sub isValid
{
	my ($date) = @_;

	return defined(str2time($date));
}


sub mdy
{
	return time2str($Options{'def_fmt'}, $_[0]);
}


sub today
{
	return mdy(time());
}


sub incDays
{
	my ($date, $inc) = @_;
	debuggit(3 => "incDays: args are", $date, $inc);

	my $secs = _cvt_date_if_necessary($date);
	debuggit(3 => "seconds before increment:", $secs);
	$secs += ($inc * 24 * 60 * 60);										# increment seconds by that many days
	$secs += 60 * 60;													# extra hour fixes DST problem
	debuggit(3 => "seconds after increment:", $secs);

	return mdy($secs);
}


# this returns the difference in days between two dates (older date first)
# it will return undef if either date is invalid
# it will return a negative number if you put the newer date first
# if you send it only one date, it will return the difference between that date and today
sub dayDiff
{
	my ($old_date, $new_date) = @_;

	my $old_secs = _cvt_date_if_necessary($old_date);
	my $new_secs = defined($new_date) ? _cvt_date_if_necessary($new_date) : time();
	return undef unless defined($old_secs) and defined($new_secs);

	my $diff_secs = $new_secs - $old_secs;
	return int($diff_secs / (24 * 60 * 60));
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

	print STDERR "Barefoot::date: dateTimeSeconds() is depracated; use Date::Parse's str2time() instead\n";
	$date = "$date $time" if $time;
	return str2time($date);
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
###########################################################################

sub period_num
{
	my ($date, $period_len, $epoch) = @_;
	$epoch = $Options{'epoch'} unless defined $epoch;
	debuggit(3 => "period_num: using epoch", $epoch);

	debuggit(3 => "period_num: ", int(dayDiff($epoch, $date) / $period_len));
	return int(dayDiff($epoch, $date) / $period_len);
}


sub period_name
{
	my ($period_num, $period_len, $epoch) = @_;
	$epoch = $Options{'epoch'} unless defined $epoch;
	debuggit(3 => "period_num: using epoch", $epoch);

	my $start = incDays($epoch, $period_num * $period_len);
	my $end = incDays($start, $period_len - 1);
	debuggit(3 => "period_name: start is", $start, "/ end is", $end);

	return "$start - $end";
}


###########################################################################
#
# import function (must be in "real" package as opposed to date::
#
###########################################################################

package Barefoot::date;

use strict;
use warnings;

use Carp;

use Barefoot;

sub import
{
	my ($class, %opts) = @_;

	debuggit(5 => "in import for date.pm");
	foreach (keys %opts)
	{
		debuggit(4 => "trying to set option", $_);
		if (exists $Options{$_})
		{
			$Options{$_} = $opts{$_};
			$Options{'overriden'}->{$_} = 1;
		}
		else
		{
			croak("cannot set unknown option $_ in date module");
		}
	}
}


###########################
# Return a true value:
###########################

1;
