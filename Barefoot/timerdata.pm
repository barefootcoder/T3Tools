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
	local $/ = "\cX\n";
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


###########################################################################
#	TIMER ROUTINES
###########################################################################

sub this_week_totals
{
	my ($user) = @_;

	# we'll have to do the rounding in three goes for the three types
	# of rounding ... let's start by building up this rather complex
	# expression bit by bit so we can easily see what's going on
	# (also we can use some of the pieces in the queries below)
	#
	# first, figure out what "now" means in Sybase
	# HACK ALERT! our server is perpetually an hour off, so we'll adjust here
	my $now = "dateadd(hour, 1, getdate())";
	# if the end_time is NULL, we're still timing, so use current time
	my $end = "isnull(tc.end_time, $now)";
	# now, figure out the number of seconds in each chunk
	my $seconds = "datediff(second, tc.start_time, $end) / tc.divisor";
	# add up all chunks and round up to the nearest minute
	my $minutes = "ceiling(sum($seconds) / 60.0)";
	# now turn into hours
	my $hours = "$minutes / 60.0";
	# now we can round the hours appropriately and multiply back by to nearest
	my %rounded_hours;
	$rounded_hours{U} = "ceiling($hours / c.to_nearest) * c.to_nearest";
	$rounded_hours{D} = "floor($hours / c.to_nearest) * c.to_nearest";
	$rounded_hours{O} = "round($hours / c.to_nearest, 0) * c.to_nearest";

	# we need to know Monday's date to get this week's time already logged
	my $monday = date::MondayDate();

	# do the SQL to get the table correct for totals
	my $result = run_query qq(

			-- clean out pay_amount
			delete pay_amount

			-- we need three of these ... I probably should do a loop,
			-- but this saves me doing separate connections to the DB
			-- without having to build up the query as a long complex
			-- string beforehand

			select t.login, t.timer_name, t.client, t.proj, t.phase,
					max($end) "date", $rounded_hours{U} "hours"
			into #timer_totals
			from timer t, timer_chunk tc, client c
			where t.login = '$user'
			and t.login = tc.login
			and t.timer_name = tc.timer_name
			and t.client = c.client
			and c.rounding = 'U'
			group by t.login, t.timer_name, t.client, t.proj, t.phase,
					c.to_nearest

			insert #timer_totals
			select t.login, t.timer_name, t.client, t.proj, t.phase,
					max($end), $rounded_hours{D}
			from timer t, timer_chunk tc, client c
			where t.login = '$user'
			and t.login = tc.login
			and t.timer_name = tc.timer_name
			and t.client = c.client
			and c.rounding = 'D'
			group by t.login, t.timer_name, t.client, t.proj, t.phase,
					c.to_nearest

			insert #timer_totals
			select t.login, t.timer_name, t.client, t.proj, t.phase,
					max($end), $rounded_hours{O}
			from timer t, timer_chunk tc, client c
			where t.login = '$user'
			and t.login = tc.login
			and t.timer_name = tc.timer_name
			and t.client = c.client
			and c.rounding = 'O'
			group by t.login, t.timer_name, t.client, t.proj, t.phase,
					c.to_nearest

			-- get all times for outstanding timers
			insert pay_amount
				(log_source, log_id, emp, client, proj, phase, date, hours,
						requires_payment, requires_billing)
			select 'timer', 0, e.emp, tt.client, tt.proj, tt.phase, tt.date,
					tt.hours, pt.requires_payment, pt.requires_billing
			from #timer_totals tt, employee e, project p, project_type pt
			where tt.login = e.login
			and tt.client = p.client
			and tt.proj = p.proj
			and tt.date between p.start_date and p.end_date
			and p.proj_type = pt.proj_type

			-- get any time that has already been logged for "this week"
			insert pay_amount
				(log_source, log_id, emp, client, proj, phase, date, hours,
						requires_payment, requires_billing)
			select tl.log_source, tl.log_id, tl.emp, tl.client,
					tl.proj, tl.phase, tl.date, tl.hours,
					pt.requires_payment, pt.requires_billing
			from time_log tl, employee e, project p, project_type pt
			where tl.emp = e.emp
			and e.login = '$user'
			and tl.date between '$monday' and dateadd(day, 6, '$monday')
			and tl.client = p.client
			and tl.proj = p.proj
			and tl.date between p.start_date and p.end_date
			and p.proj_type = pt.proj_type

			-- figure out pay amounts
			exec calc_pay_amount

			-- this should really be handled by the stored procedure,
			-- but, since it isn't right now, we'll do it
			update pay_amount
			set pay_rate = 0
			where requires_payment = 0

			go
	);
	my $rows_affected = '\(\d+ rows? affected\)';
	my $result_pattern = ($rows_affected . '\n') x 6
			. '\(return status = 0\)\n' . $rows_affected;
	# print STDERR ">>$result<<\n>>$result_pattern<<\n" and
	return undef unless $result =~ /\A$result_pattern\Z/;

	# now get the results
	my $totals = query_results("

		select pa.client, c.name, pa.pay_rate, sum(pa.hours)
		from pay_amount pa, client c
		where pa.client = c.client
		group by pa.client, c.name, pa.pay_rate

	");

	# and get bad project rows
	my $bad_proj = timerdata::query_results("

		select t.client, $hours
		from timer t, timer_chunk tc
		where t.login = '$user'
		and t.login = tc.login
		and t.timer_name = tc.timer_name
		and not exists
		(
			select 1
			from project p
			where t.client = p.client
			and t.proj = p.proj
			and $end between p.start_date and p.end_date
		)
		group by t.client

	");

	return ($totals, $bad_proj);
}
