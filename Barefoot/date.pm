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


# this one just tests for a valid date and returns 1 or 0
# it accepts the following forms:
#	mm/dd/yy
#	mm/dd/yyyy
#	mm-dd-yy
#	mm-dd-yyyy
# month and day numbers may be only one digit
sub isValid
{
	my ($date) = @_;

	my ($mon, $day, $year) = split(?/|-?, $date);
	--$mon;									# timelocal expects this
	$year -= 1900 if $year >= 100;			# account for 2 or 4 digit years;
	eval { timelocal(0,0,0,$day,$mon,$year) };
	return $@ ? 0 : 1;
}

sub incDays
{
	my ($date, $inc) = @_;
	# print "$date, $inc\n";

	my ($year, $mon, $day) = $date =~ /(\d\d\d\d)(\d\d)(\d\d)/;
	# print "$mon, $day, $year\n";

	$year -= 1900, --$mon;				# adjust values for timelocal
	my $secs = timelocal(0, 0, 12, $day, $mon, $year);
	$secs += ($inc * 24 * 60 * 60);		# increment seconds by that many days

	($day, $mon, $year) = (localtime $secs)[3..5];
	$year += 1900, ++$mon;

	return $year . string::lpad($mon, 2, 0) . string::lpad($day, 2, 0);
}

sub sortableString
{
	my ($sep) = @_;

	$sep = "" if !defined($sep);		# separator for elements
	my $date = `date "+%Y$sep%m$sep%d$sep%H$sep%M$sep%S"`;
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