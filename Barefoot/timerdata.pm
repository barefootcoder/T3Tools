#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# $Id$
# $Revision$

###########################################################################
#
# timerdata
#
###########################################################################
#
# Routines to access data from the timer application
#
###########################################################################

package timerdata;

### Private ###############################################################

use strict;


#
# Constants:
#

my $SERVER		= 'SYBASE_1';
my $USER		= 'guest';
my $TIMERDB		= 'TIMER';


1;


#
# Subroutines:
#



# generic query returner
sub query_results
{
	my ($sql_query) = @_;
	$sql_query =~ s/"/'/g;		# change " to ' so shell can process correctly
	my $rows = [];

	open(SQL, "get_sql \"$sql_query\" -S$SERVER -U$USER -D$TIMERDB -d\cX |")
			or warn("can't get results from get_sql") and return undef;
	while ( <SQL> )
	{
		chomp;
		s/^\cX//;		# line starts with \cX, which would make a blank field
		my @cols = split(/\cX/);
		# gotta trim up the fields because the headers cause all kinds
		# of funky spaces (both front and back)
		foreach my $col (@cols)
		{
			$col = string::alltrim($col);
		}
		push @$rows, \@cols;
	}
	close(SQL);

	return $rows;
}

# support routine (not to be called from outside
sub _getsql
{
}


###########################################################################
#	EMPLOYEE ROUTINES
###########################################################################

sub emp_number
{
	my ($login_name) = @_;

	my $query = "select emp from employee where login = '$login_name'";
	my $answer = `get_sql "$query" -S$SERVER -U$USER -D$TIMERDB`;
	chomp $answer;
	return $answer;
}


###########################################################################
#	CLIENT ROUTINES
###########################################################################

sub client_name
{
	my ($client_num) = @_;

	my $query = "select name from client where client = '$client_num'";
	my $answer = `get_sql "$query" -S$SERVER -U$USER -D$TIMERDB`;
	chomp $answer;
	return $answer;
}

sub client_rounding
{
	my ($client_num) = @_;

	my $query = "select rounding from client where client = '$client_num'";
	my $answer = `get_sql "$query" -S$SERVER -U$USER -D$TIMERDB`;
	chomp $answer;
	return $answer;
}

sub default_client
{
	my ($login_name) = @_;
	
	my $query = "select defclient from employee where login = '$login_name'";
	my $answer = `get_sql "$query" -S$SERVER -U$USER -D$TIMERDB`;
	chomp $answer;
	return $answer;
}
