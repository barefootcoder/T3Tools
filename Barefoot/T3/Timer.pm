#! /usr/local/bin/perl -w

# For CVS:
# $Date: 2003/04/02 20:23:17 $
#
# $Id: Timer.pm,v 1.7 2003/04/02 20:23:17 buddy Exp $
# $Revision: 1.7 $

###########################################################################
#
# Barefoot::T3::Timer
#
###########################################################################
#
# Some general functions that are specific to the Timer module.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package Barefoot::T3::Timer;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw<timer_command readfile calc_time calc_date test_connection
		this_week_totals>;

use Date::Parse;
use Date::Format;

use Barefoot::base;
use Barefoot::range;
use Barefoot::exception;

use Barefoot::T3::base;


# Timer command map
our %timer_commands =
(
	START		=>	\&start,
	PAUSE		=>	\&pause,
	CANCEL		=>	\&cancel,
	DONE		=>	\&done,
	LIST		=>	\&list,
	RENAME		=>	\&rename,
	LOG			=>	\&log_time,
);


###########################
# Helper Procedures
###########################


sub _remove_timer
{
	my ($opts, $command, $timers, $timer_to_remove) = @_;
	print STDERR "entering _remove_timer\n" if DEBUG >= 5;

	# save to history file, get rid of timer, and reset current timer marker
	# if the removed timer is the current one

    my $del_timer = delete $timers->{$timer_to_remove};
    save_history($command, $opts->{user}, $del_timer);

    if (exists $timers->{T3::CURRENT_TIMER}
			and $timers->{T3::CURRENT_TIMER} eq $timer_to_remove)
    {
        delete $timers->{T3::CURRENT_TIMER};
    }
}


###########################
# Subroutines:
###########################


sub timer_command
{
	my ($command, $opts, $timers) = @_;
	print "in timer_command with $command\n" if DEBUG >= 4;

	die("command not supported ($command)")
			unless exists $timer_commands{$command};
	die("half-time flag only makes sense when starting a timer")
			if $opts->{halftime} and $command ne 'START';

	# run command
	# if there is an error, it will throw an exception
	# return value of command indicates whether or not it is necessary
	# to save data (not all commands modify the timer list)
	if ($timer_commands{$command}->($opts, $timers))
	{
		print STDERR "about to write file\n" if DEBUG >= 5;
		writefile($opts->{user}, $timers);
		print STDERR "back from writing file\n" if DEBUG >= 5;
	}
}


sub readfile
{
	my ($user) = @_;

	my $timers = {};

	open(TFILE, T3::base_filename(TIMER => $user))
			or die("can't read timer file");
	while ( <TFILE> )
	{
		chomp;
		my $timer = {};
		(timer_fields($timer)) = split("\t", $_, -1);
		$timers->{$timer->{name}} = $timer;
		if ($timer->{time} =~ /-$/)
		{
			print STDERR "readfile: setting current timer to $timer->{name}\n"
					if DEBUG >= 3;
			$timers->{T3::CURRENT_TIMER} = $timer->{name};
		}
	}
	close(TFILE);

	return $timers;
}


sub writefile
{
	my ($user, $timers) = @_;
	print STDERR "entering writefile function\n" if DEBUG >= 5;

	# don't really care whether this succeeds or not
	try
	{
		print STDERR "in try block\n" if DEBUG >= 5;
		save_to_db($user, $timers);
	}
	catch
	{
		print "returning from catch block\n" if DEBUG >= 5;
		return;					# from catch block
	};
	print STDERR "made it past exception block\n" if DEBUG >= 5;

	my $tfile = T3::base_filename(TIMER => $user);
	print STDERR "going to print to file $tfile\n" if DEBUG >= 3;
	open(TFILE, ">$tfile") or die("can't write to timer file");
	while (my ($name, $timer) = each %$timers)
	{
		# ignore tags
		next if substr($name, 0, 1) eq ':';

		$timer->{phase} ||= "";
		$timer->{todo_link} ||= "";
		print TFILE join("\t", timer_fields($timer)), "\n";
	}
	close(TFILE);
}


sub save_history
{
	my ($command, $user, $timer) = @_;
	print STDERR "entering save_history function\n" if DEBUG >= 5;

	my $hfile = T3::hist_filename(TIMER => $user);
	print STDERR "going to print to file $hfile\n" if DEBUG >= 3;
	open(HFILE, ">>$hfile") or die("can't write to history file");

	$timer->{phase} ||= "";
	$timer->{todo_link} ||= "";
	print HFILE join("\t", $ENV{USER}, time2str("%L/%e/%Y %l:%M%P", time),
			$command, $user, timer_fields($timer)), "\n";

	close(HFILE);
}



###########################
# Calculation Procedures
###########################


sub calc_time
{
	my ($line) = @_;
	my @times = split(',', $line);
	my $total_time = 0;

	my $current_time = false;
	foreach my $time (@times)
	{
		if ($time =~ /^([+-]\d+)$/)
		{
			$total_time += $1 * 60;
			next;
		}

		my ($divisor, $from, $to) = $time =~ m{(?:(\d+)/)?(\d+)-(\d+)?};
		die("illegal format in time file") unless $from;
		if (!$to)
		{
			die("more than one current time in time file") if $current_time;
			$current_time = true;
			$to = time;
		}
		$total_time += ($to - $from) / ($divisor ? $divisor : 1);
	}
	return range::round($total_time / 60, range::ROUND_UP);
}


sub calc_date
{
	my ($line) = @_;

	my $seconds;
	if ($line and $line =~ /(\d+),$/)	# ends in a comma, must be paused
	{
		$seconds = $1;
	}
	else								# current or no time given
	{
		$seconds = time;
	}

	# adjust for working after midnight ... if the time is before 6am,
	# we'll just subtract a day
	my ($hour) = (localtime $seconds)[2];
	$seconds -= 24*60*60 if $hour < 6;

	my ($day, $mon, $year) = (localtime $seconds)[3..5];
	#return ++$mon . "/" . $day . "/" . ($year + 1900);
	return ($year + 1900) . "-" . ++$mon . "-" . $day;
}



###########################
# Database Procedures
###########################


my $connected;

sub test_connection
{
	print STDERR "Entered test_connection\n" if DEBUG >= 5;

	if (defined $connected)
	{
		# presumably, this means that we've been here before
		# let's just save time and return what we found out last time
		return $connected;
	}

	$connected = &t3->ping();
	if (DEBUG >= 4)
	{
		print STDERR
				$connected
					? "Leaving test_connection w/o error"
					: ("test_connection got error: " . &t3->last_error())
				,
				"\n";
	}

	return $connected;
}


sub insert_time_log
{
	my ($user, $emp, $client, $proj, $phase, $tracking, $date,
			$hours, $comments) = @_;

	my $query = '
			insert into {@time_log}
				(	emp_id, client_id, proj_id, phase_id, tracking_code,
					log_date, hours, comments,
					create_user, create_date
				)
			values
			(	{emp}, {client}, {proj}, {phase}, {tracking},
				{date}, {hours}, {comments},
				{user}, {&curdate}
			)
	';

	print STDERR "$query\n" if DEBUG >= 3;
	my $result = &t3->do($query,
			emp => $emp, client => $client, proj => $proj, phase => $phase,
			tracking => $tracking, date => $date, hours => $hours,
			comments => $comments, user => $user,
	);
	die("database error: ", &t3->last_error())
			unless defined $result and $result->rows_affected() == 1;
	return true;
}


sub save_to_db
{
	my ($user, $timers) = @_;
	print STDERR "Entered save_to_db\n" if DEBUG >= 5;

	# get the workgroup user ID because just about every query needs that
	my $wuser_data = &t3->load_table("select wuser_id "
			. "from {\@workgroup_user} where nickname = '$user'");
	# sneaky way to quickly get a datum: 1st col of 1st row of "entire" table
	my $wuser_id = $wuser_data->[0]->[0];
	print STDERR "got workgroup user id $wuser_id\n" if DEBUG >= 2;

	my $posted_timers = &t3->do('

			select t.timer_name
			from {@timer} t
			where t.wuser_id = {wuser_id}
	',
			wuser_id => $wuser_id
	);
	return false unless $posted_timers;

	# see what timer names are already in the db
	my $db_timernames = {};
	while ($posted_timers->next_row())
	{
		$db_timernames->{$posted_timers->col('timer_name')} = 1;
	}

	while (my ($tname, $timer) = each %$timers)
	{
		# ignore tags
		next if substr($tname, 0, 1) eq ':';

		print STDERR "Calling db_post_timer for $tname\n" if DEBUG >= 3;
		return false unless db_post_timer($wuser_id, $tname, $timer,
				$db_timernames);
	}

	while (my $tname = each %$db_timernames)
	{
		print STDERR "Deleting leftover db timer $tname\n" if DEBUG >= 3;
		db_delete_timer($wuser_id, $tname);
	}

	print STDERR "Leaving save_to_db w/o error\n" if DEBUG >= 5;
	return true;
}


sub db_post_timer
{
	my ($wuser_id, $tname, $timer, $timernames) = @_;
	print STDERR "Entered db_post_timer, processing $tname\n" if DEBUG >= 5;

	# if the name was found in the list ...
	if ( exists $timernames->{$tname} )
	{
		print STDERR "Removing old timer $tname from list\n" if DEBUG >= 3;
		# if it hasn't been posted ...
		if (not $timer->{posted})
		{
			# try to delete it from the db
			print STDERR "Deleting old timer $tname from db before posting\n"
					if DEBUG >= 2;
			return false unless db_delete_timer($wuser_id, $tname);
		}
		# remove it from the list
		delete $timernames->{$tname};
	}
	else
	{
		# not found in the list, mark it as unposted
		$timer->{posted} = false;
	}

	# if it hasn't been posted ...
	if (not $timer->{posted})
	{
		print STDERR "Posting unposted timer $tname\n" if DEBUG >= 2;

		my $result = &t3->do('

				insert into {@timer}
					(wuser_id, timer_name, client_id, proj_id, phase_id)
				values
					( {wuser_id}, {timer_name}, {client}, {proj}, {phase} )
		',
				wuser_id => $wuser_id, timer_name => $tname,
				client => $timer->{client}, proj => $timer->{project},
				phase => $timer->{phase},
		);
		print STDERR &t3->last_error() and return false
				unless $result and $result->rows_affected() == 1;

		foreach my $chunk (split(',', $timer->{time}))
		{
			print STDERR "post_timer: chunk is $chunk, " if DEBUG >= 2;
			my $success = $chunk =~ s@^(\d+)/@@;
			my $divisor = $success ? $1 : 1;
			print STDERR "divisor is $divisor\n" if DEBUG >= 2;

			my ($start_secs, $end_secs) = split('-', $chunk);
			my $start = time2str("%b %d, %Y %H:%M:%S", $start_secs);
			my $end = $end_secs
					? time2str("%b %d, %Y %H:%M:%S", $end_secs)
					: undef;

			my $result = &t3->do('

					insert into {@timer_chunk}
						(wuser_id, timer_name, divisor, start_time, end_time)
					values
						( {wuser_id}, {timer_name}, {divisor},
								{start_time}, {end_time} )
			',
					wuser_id => $wuser_id,
					timer_name => $tname, divisor => $divisor,
					start_time => $start, end_time => $end,
			);
			print STDERR &t3->last_error() and return false
					unless $result and $result->rows_affected() == 1;
		}

		# note that timers that are still timing (easy to tell because their
		# time chunks string ends in a dash) are never considered posted
		$timer->{posted} = true unless substr($timer->{time}, -1) eq '-';
	}

	print STDERR "Leaving db_post_timer w/o error\n" if DEBUG >= 5;
	return true;
}


sub db_delete_timer
{
	my ($wuser_id, $tname) = @_;
	print STDERR "Entered db_delete_timer: timer $tname, user $wuser_id\n"
			if DEBUG >= 4;

	my $result = &t3->do('

			delete from {@timer_chunk}
			where wuser_id = {wuser_id}
			and timer_name = {timer_name}
	',
		wuser_id => $wuser_id, timer_name => $tname,
	);
	return false unless $result;
	print STDERR "First delete (timer_chunk) finished w/o error\n"
			if DEBUG >= 5;

	$result = &t3->do('

			delete from {@timer}
			where wuser_id = {wuser_id}
			and timer_name = {timer_name}
	',
		wuser_id => $wuser_id, timer_name => $tname,
	);
	return false unless $result and $result->rows_affected() == 1;

	print STDERR "Leaving db_delete_timer w/o error\n" if DEBUG >= 5;
	return true;
}


sub this_week_totals
{
=comment
	my ($user, $timers) = @_;

	# better make sure db is sync'ed with file
	save_to_db($user, $timers);

	#&t3->{dbh}->func('LONG', '_date_fmt');

	my $timer_data = &t3->load_data(q<

			select t.timer_name, t.client_id, t.proj_id, t.phase_id,
					tc.start_time, tc.end_time, tc.divisor,
					c.rounding, c.to_nearest
			from {@workgroup_user} wu, {@timer} t, {@timer_chunk} tc,
					{@client} c
			where wu.nickname = {user}
			and wu.wuser_id = t.wuser_id
			and t.wuser_id = tc.wuser_id
			and t.timer_name = tc.timer_name
			and t.client_id = c.client_id

	>, user => $user);
	die("database error: " . &t3->last_error()) unless defined $timer_data;

	$timer_data = $timer_data->group(
			group_by		=>	[ qw<timer_name> ],
			new_columns		=>	[ qw<timer_name seconds client_id proj_id>,
									qw<phase_id rounding to_nearest> ],
			constant		=>	[ qw<client_id proj_id phase_id>,
									qw<rounding to_nearest> ],
			on_new_group	=>	sub
								{
									$_->{seconds} = 0;
								},
			calculate		=>	sub
			{
				my ($src, $dst) = @_;

				# ditch milliseconds if there
				$src->{start_time} =~ s/:\d\d\d//;
				$src->{end_time} =~ s/:\d\d\d// if $src->{end_time};

				$src->{start_time} = str2time($src->{start_time});
				$src->{end_time} = defined $src->{end_time}
						? str2time($src->{end_time})
						: time();

				$dst->{seconds} += ($src->{end_time} - $src->{start_time})
						/ $src->{divisor};
			}
	);

	$timer_data->alter_dataset({
			add_columns		=>	[ qw<log_source log_id emp_id hours> ],
			remove_columns	=>	[ qw<seconds rounding to_nearest> ],
			foreach_row		=>	sub
			{
				$_->{log_source} = 'timer';
				$_->{log_id} = 0;

				$_->{emp_id} = '000';

				my $minutes = range::round($_->{seconds} / 60,
						range::ROUND_UP);
				$_->{hours} = range::max(range::round($minutes / 60,
						$_->{rounding}, $_->{to_nearest}), $_->{to_nearest});
			},
	});

	$timer_data->dump_set();

	&t3->replace_table('@pay_amount', $timer_data);

				#$_->{hours} = range::round($minutes / 60, $_->{rounding},
				#		$_->{to_nearest});
	# we'll have to do the rounding in three goes for the three types
	# of rounding ... let's start by building up this rather complex
	# expression bit by bit so we can easily see what's going on
	# (also we can use some of the pieces in the queries below)
	#
	# first, figure out what "now" means
	my @ltime = localtime(time);
	my $now = strftime("%b %e %Y %l:%M%p", @ltime);
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
	my $result = run_query <<END;

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
END
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
=cut

	die("timer -t not implemented yet");
	#return ($totals, $bad_proj);
}


###########################
# Command Procedures
###########################


sub start                   # start a timer
{
	my ($opts, $timers) = @_;
	my $timersent = $opts->{timer};
	print STDERR "start: going to start timer $timersent\n" if DEBUG >= 3;

	# figure out current timer (if any)
	my $curtimer = $timers->{T3::CURRENT_TIMER} || "";
	print STDERR "start: current timer is $curtimer\n" if DEBUG >= 2;

	# if new and old are the same, make sure a difference in full/half is
	# being requested, else it's an error
    if ($timersent eq $curtimer)
	{
		# $halftime indicates if timer is currently running in halftime mode
		# $givenhalftime indicates if halftime is being requested

		my $halftime = $timers->{$curtimer}->{time}
				=~ m{ 2/ \d+ - $ }x;
		my $givenhalftime = $opts->{halftime} || 0;

		if ($halftime == $givenhalftime)
		{
			print STDERR "start error; dying\n" if DEBUG >= 4;
			die("Timer already started in that mode");
		}
	}

	# if currently timing, pause the current timer
	if ($curtimer)
	{
		print STDERR "going to pause current timer\n" if DEBUG >= 4;
		$timers->{$curtimer}->{time} .= time . ',';
		$timers->{$curtimer}->{posted} = false;
	}

	# if not restarting an existing timer, got to build up some structure
    if (not exists $timers->{$timersent})
	{
		$timers->{$timersent}->{name} = $timersent;

		foreach my $attrib ( qw<client project phase todo_link> )
		{
			$timers->{$timersent}->{$attrib} = $opts->{$attrib} || "";
		}
	}

	# add start time, mark unposted
	$timers->{$timersent}->{time} .=
			($opts->{halftime} ? "2/" : "") . time . '-';
	$timers->{$timersent}->{posted} = false;

	# change current timer marker (in case caller wishes to display something)
	$timers->{T3::CURRENT_TIMER} = $timersent;

	# need to write the file
	return true;
}


sub pause                   # pause all timers
{
	my ($opts, $timers) = @_;

	# make sure pause makes sense
    my $curtimer = $timers->{T3::CURRENT_TIMER};
    if (!$curtimer)
    {
		die("No timer is running");
    }

	# provide end time, mark unposted, clear current timer
    $timers->{$curtimer}->{time} .= time . ',';
    $timers->{$curtimer}->{posted} = false;
    delete $timers->{T3::CURRENT_TIMER};

	# need to write the file
	return true;
}


sub cancel                   # cancel a timer
{
	my ($opts, $timers) = @_;
	my $timersent = $opts->{timer};

	# make sure timer to cancel really exists
   	unless (exists $timers->{$timersent})
    {
		die("Can't cancel; no such timer");
    }

	# get rid of timer
	_remove_timer($opts, CANCEL => $timers, $timersent);

	# need to write the file
	return true;
}


sub done					# done with a timer
{
	my ($opts, $timers) = @_;
	my $timersent = $opts->{timer};
	print "entering done function\n" if DEBUG >= 5;

    unless (exists $timers->{$timersent})
    {
		die("No such timer as $timersent");
    }

	# cheat by calling the log command, which does exactly what we need
	log_time($opts, $timers);
	print STDERR "logged time, about to call _remove_timer\n" if DEBUG >= 5;

	# get rid of timer
	_remove_timer($opts, DONE => $timers, $timersent);

	# need to write the file
	return true;
}


sub log_time				# log time not connected to a timer
{
	my ($opts, $timers) = @_;

	# build arg list for insert_time_log and make sure all are there
	my @insert_args = ();
	foreach my $attrib ( qw<user employee client project phase>,
			qw<tracking date hours comments> )
	{
		die("cannot log to database without attribute $attrib")
				unless exists $opts->{$attrib};
		push @insert_args, $opts->{$attrib};
	}

	# stuff it into the database (this dies if it fails)
	insert_time_log(@insert_args);

	# surprisingly, no need to write the file on this one
	return false;
}


sub list
{
	my ($opts, $timers) = @_;

	# nothing to do, and no need to write the file
	return false;
}


sub rename                   # new name for a timer
{
	my ($opts, $timers) = @_;

    # just a shortcut here
    my $oldname = $opts->{timer};
    unless (exists $timers->{$oldname})
    {
		die("Can't rename; no such timer");
    }

    if (not $opts->{newtimer})
    {
		die("New name not specified");
    }

    my $newname = $opts->{newtimer};

    # if changing timer name
    if ($newname ne $oldname)
    {
		# can't rename to same name as an existing timer, of course
        if (exists $timers->{$newname})
        {
			die("That timer already exists");
        }

		# change name attribute
		$timers->{$oldname}->{name} = $newname;
		# copy old to new
        $timers->{$newname} = $timers->{$oldname};
		# delete new
        delete $timers->{$oldname};
    }

    # change other parameters
	# (not checking these against database)
    $timers->{$newname}->{client} = $opts->{client} if $opts->{client};
    $timers->{$newname}->{project} = $opts->{project} if $opts->{project};
    $timers->{$newname}->{phase} = $opts->{phase} if $opts->{phase};

	# timer should be marked unposted so changes can go to database
	$timers->{$newname}->{posted} = false;

	# switch current timer marker if renaming current timer
    $timers->{T3::CURRENT_TIMER} = $newname
			if exists $timers->{T3::CURRENT_TIMER}
					and $timers->{T3::CURRENT_TIMER} eq $oldname;

	# need to write the file
	return true;
}


###########################
# Return a true value:
###########################

1;
