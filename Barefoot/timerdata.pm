#! /usr/local/bin/perl

# For RCS:
# $Date$
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

use Barefoot::string;


#
# Pseudo-Constants:
#

my $SERVER		= 'SYBASE_1';
my $USER		= 'guest';
my $TIMERDB		= $::ENV{TIMERTEST} ? $::ENV{TIMERTEST} : 'timer';


1;


#
# Subroutines:
#


# change connection parameters
sub set_connection
{
	my ($db_server, $db_name, $user) = @_;

	$SERVER = $db_server;
	$TIMERDB = $db_name;
	set_user($user) if $user;
}

# change user
sub set_user
{
	my ($newuser) = @_;

	$USER = $newuser;
}

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

# generic query runner ... returns isql output, generally in the form
# "(X rows affected)" as long as you give it inserts/updates/deletes
# for selects, see above function
sub run_query
{
	my ($query) = @_;

	$query =~ s/^\s*go\s*$/go/mg;
	# print "sending to run_query: >>\n$query\n<<\n";

	my $result = `echo "$query" | run_query -S$SERVER -U$USER -D$TIMERDB`;
	chomp $result;
	return $result;
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

	return _getsql("select rtrim(fname) + ' ' + rtrim(lname) from employee "
			. "where emp = '$emp_number'");
}

sub default_client
{
	my ($login_name) = @_;
	
	return _getsql("select def_client from employee "
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

	my $output = _getsql("select rounding, to_nearest from client " .
			"where client = '$client_num'");
	my ($rounding, $to_nearest) = split(" ", $output);
	return ($rounding, $to_nearest);
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
	my ($client, $proj, $date) = @_;

	my $row = _getsql("
			select pt.requires_phase, pt.requires_cliproj, pt.requires_comments
			from project p, project_type pt
			where p.client = '$client'
			and p.proj = '$proj'
			and '$date' between p.start_date and p.end_date
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
			insert time_log
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
