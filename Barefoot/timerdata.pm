#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# Revision 1.1  1999/05/02 06:23:39  buddy
# Initial revision
#
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

# support routine (not to be called from outside)
sub _getsql
{
	my ($query) = @_;
	my $answer = `get_sql "$query" -S$SERVER -U$USER -D$TIMERDB`;
	chomp $answer;
	return $answer;
}


###########################################################################
#	EMPLOYEE ROUTINES
###########################################################################

sub emp_number
{
	my ($login_name) = @_;

	return _getsql("select emp from employee where login = '$login_name'");
}

sub emp_fullname
{
	my ($emp_number) = @_;

	return _getsql("select rtrim(name) + ' ' + rtrim(lname) from employee "
			. "where emp = '$emp_number'");
}

sub default_client
{
	my ($login_name) = @_;
	
	return _getsql("select defclient from employee "
			. "where login = '$login_name'");
}


###########################################################################
#	CLIENT ROUTINES
###########################################################################

sub client_name
{
	my ($client_num) = @_;

	return _getsql("select name from client where client = '$client_num'");
}

sub client_rounding
{
	my ($client_num) = @_;

	return _getsql("select rounding from client where client = '$client_num'");
}


###########################################################################
#	PROJECT ROUTINES
###########################################################################

sub proj_name
{
	my ($client, $proj) = @_;

	return _getsql("select name from project where client = '$client' "
			. "and proj = '$proj'");
}

sub proj_requirements
{
	my ($client, $proj) = @_;

	my $row = _getsql("
			select pt.requires_phase, pt.requires_cliproj, pt.requires_comments
			from project p, project_type pt
			where p.client = '$client'
			and p.proj = '$proj'
			and p.proj_type = pt.proj_type
		");
	return split(" ", $row);
}


###########################################################################
#	PHASE ROUTINES
###########################################################################

sub phase_name
{
	my ($phase) = @_;

	return _getsql("select name from phase where phase = '$phase'");
}


###########################################################################
#	CLIPROJ ROUTINES
###########################################################################

sub cliproj_name
{
	my ($client, $cliproj) = @_;

	return _getsql("select name from cliproj where client = '$client' "
			. "and project_id = '$cliproj'");
}


###########################################################################
#	LOG ROUTINES
###########################################################################

sub insert_log
{
	my ($emp, $client, $proj, $phase, $cliproj, $date, $hours, $comments) = @_;

	$emp = "'$emp'";
	$client = "'$client'";
	$proj = "'$proj'";
	$phase = defined($phase) ? "'$phase'" : "null";
	$cliproj = defined($cliproj) ? "'$cliproj'" : "null";
	$date = "'$date'";
	$comments =~ s/'/''/g;			# handle literal single quotes
	$comments = defined($comments) ? "'$comments'" : "null";

	my $query = "
			insert log
				(	emp, client, proj, phase, cliproj, date, hours, comments,
					create_user, create_date
				)
			values
			(	$emp, $client, $proj, $phase, $cliproj, $date, $hours,
				$comments,
				'$ENV{USER}', getdate()
			)
go
		";
	# print "$query\n";
	my $result = `echo "$query" | run_query -S$SERVER -U$USER -D$TIMERDB`;
	chomp $result;
	# print "<<$result>>\n";
	return $result eq "(1 row affected)" ? "" : $result;
}
