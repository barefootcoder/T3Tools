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

use string;


1;


#
# Subroutines:
#


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
