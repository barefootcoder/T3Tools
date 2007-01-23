#! /usr/bin/perl

# ---------------------------------------------------------------------------

package Barefoot::T3Timer;

use strict;

#use Barefoot::debug(4);							# comment out for production

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw<>;


use Storable;
use Data::Dumper;
use POSIX qw<strftime>;

use Barefoot::base;
use Barefoot::file;
use Barefoot::date;
use Barefoot::array;
use Barefoot::range;
use Barefoot::exception;
use Barefoot::DataStore;
use Barefoot::config_file;

use Barefoot::T3::base;
use Barefoot::T3::Timer qw<timer_command readfile calc_date calc_time>;


# Timer constants


unless ($ENV{USER})
{
	$ENV{USER} = "www";
	$ENV{HOME} = "/home/www";
	$ENV{SYBASE} = "/opt/sybase";
	$ENV{PATH} .= ":/opt/sybase/bin:/usr/local/dbutils:/opt/sybase";
}


true;



# ------------------------------------------------------------
# Main Procedures
# ------------------------------------------------------------

sub processMessage
{
	my ($message) = @_;

	my $timerinfo = {};
	my $send = "";

	try
	{
		# transfer some stuff from $message to $timerinfo
		# the loop is the stuff that transfers directly
		# attributes whose names must change follow
		foreach my $attrib ( qw<halftime client project phase>,
				qw<employee tracking date hours comments> )
		{
			$timerinfo->{$attrib} = $message->{$attrib}
					if exists $message->{$attrib};
		}
		$timerinfo->{newname} = $message->{_DATA_}
				if exists $message->{_DATA_};

		$send = ack($message->{command}, $message->{name}, "OK")
				. "\n" . ping_response($timerinfo);
	}
	catch
	{
		$send = ack($message->{command}, $message->{name}, "FAIL: $_")
				. "\n" . ping_response($timerinfo);
	};

	return $send;
}


# ------------------------------------------------------------
# Database Procedures for Timer data
# ------------------------------------------------------------


=comment
sub this_week_totals
{
	my ($user) = @_;

	# we'll have to do the rounding in three goes for the three types
	# of rounding ... let's start by building up this rather complex
	# expression bit by bit so we can easily see what's going on
	# (also we can use some of the pieces in the queries below)
	#
	# first, figure out what "now" means
	my $now = strftime("%b %e %Y %l:%M%p", localtime(time));
	# if the end_time is NULL, we're still timing, so use current time
	my $end = "{&ifnull tc.end_time, '$now'}";
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
					max($end) "timer_date", $rounded_hours{U} "hours"
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
				(log_source, log_id, emp, client, proj, phase, pay_date,
						hours, requires_payment, requires_billing)
			select 'timer', 0, e.emp, tt.client, tt.proj, tt.phase,
					tt.timer_date, tt.hours, pt.requires_payment,
					pt.requires_billing
			from #timer_totals tt, employee e, project p, project_type pt
			where tt.login = e.login
			and tt.client = p.client
			and tt.proj = p.proj
			and tt.timer_date between p.start_date and p.end_date
			and p.proj_type = pt.proj_type

			-- get any time that has already been logged for "this week"
			insert pay_amount
				(log_source, log_id, emp, client, proj, phase, log_date,
						hours, requires_payment, requires_billing)
			select tl.log_source, tl.log_id, tl.emp, tl.client,
					tl.proj, tl.phase, tl.log_date, tl.hours,
					pt.requires_payment, pt.requires_billing
			from time_log tl, employee e, project p, project_type pt
			where tl.emp = e.emp
			and e.login = '$user'
			and tl.log_date between '$monday' and dateadd(day, 6, '$monday')
			and tl.client = p.client
			and tl.proj = p.proj
			and tl.log_date between p.start_date and p.end_date
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
	#die("this weeks totals function not yet implemented");
}
=cut


# ------------------------------------------------------------
# Communication Procedures
# ------------------------------------------------------------

sub ack
{
	my ($command, $name, $result) = @_;

	my $sendback = '<MESSAGE module="TIMER" command="' . $command
			. '" name="' . $name . '">' . $result . '</MESSAGE>';

	return ($sendback);
}


sub ping_response
{
	my ($timerinfo) = @_;

	my $timers = $timerinfo->{timers};
	my $lines;

	foreach my $key (keys (%$timers))
	{
		my $thistimer  = $timers->{$key};

		my $line = '<MESSAGE module="TIMER"';

# debugging lines
#		$line .= ' tfile="' . $timerinfo->{tfile} .'"';
#		$line .= ' newname="' . $timerinfo->{newname} .'"';

		$line .= ' user="' . $timerinfo->{user} .'"';
		$line .= ' name="' . $key .'"';
		$line .= ' client="' . $thistimer->{client} . '"'
				if exists $thistimer->{client};
		$line .= ' project="' . $timers->{$key}->{project} . '"'
				if exists $thistimer->{project};
		$line .= ' phase="' . $timers->{$key}->{phase} . '"'
				if exists $thistimer->{phase};

		if ($thistimer->{time} =~ /-$/)
		{
			$line = $line . ' status="ACTIVE"';
		}

		$line = $line . ' date="'
			. calc_date($thistimer->{time}) . '"';
		$line = $line . ' halftime="YES"' if $thistimer->{time} =~ m{/\d+-$};
		$line = $line . ' elapsed="' . calc_time($thistimer->{time}) . '"';

		# Not sending BD-DATA anymore
		#$line = $line . '>' . $thistimer->{time} . '</MESSAGE>';
		$line = $line . '></MESSAGE>' . "\n";

		$lines .= $line;
	}

	return $lines;
}
