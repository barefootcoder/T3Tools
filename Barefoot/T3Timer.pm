#! /usr/bin/perl

# ---------------------------------------------------------------------------

package Barefoot::T3Timer;

use strict;

#use Barefoot::debug(4);							# comment out for production

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = (qw<get_timer_info do_timer_command calc_date calc_time>,
		qw<get_emp_id default_client valid_employees valid_clients>,
		qw<valid_projects proj_requirements phase_list valid_trackings>,
		qw<client_rounding this_week_totals insert_time_log>);


use POSIX qw<strftime>;
use Storable;

use Barefoot::base;
use Barefoot::file;
use Barefoot::date;
use Barefoot::array;
use Barefoot::range;
use Barefoot::exception;
use Barefoot::DataStore;
use Barefoot::config_file;


# Timer constants

use constant CONFIG_FILE => '/etc/t3.conf';

use constant DBSERVER_DIRECTIVE => 'DBServer';
use constant DATABASE_DIRECTIVE => 'Database';
use constant TIMERDIR_DIRECTIVE => 'TimerDir';

use constant TIMEFILE_EXT => '.timer';
use constant HISTFILE => 'timer.history';

use constant DEFAULT_WORKGROUP => 'Barefoot';
#use constant DEFAULT_WORKGROUP => 'TestCompany';
use constant FALLBACK_TIMER => 'default';


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

# data store for database operations
unless ($ENV{USER})
{
	$ENV{USER} = "www";
	$ENV{HOME} = "/home/www";
	$ENV{SYBASE} = "/opt/sybase";
	$ENV{PATH} .= ":/opt/sybase/bin:/usr/local/dbutils:/opt/sybase";
}
our $t3;


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


sub get_timer_info
{
	my ($timername, $timerinfo) = @_;

	setuptimer($timername, $timerinfo);
	readfile($timerinfo);

	# try to find a more reasonable default timer
	if ($timerinfo->{giventimer} eq FALLBACK_TIMER)
	{
		if ($timerinfo->{curtimer})
		{
			# if there's a current timer, use that
			$timerinfo->{giventimer} = $timerinfo->{curtimer};
		}
		elsif (keys %{$timerinfo->{timers}} == 1)
		{
			# if there's only 1 timer, use that
			$timerinfo->{giventimer} = (keys %{$timerinfo->{timers}})[0];
		}
		# if none of those work, you're stuck with FALLBACK_TIMER
	}
}


sub do_timer_command
{
	my ($command, $timerinfo) = @_;

	# save command in case later functions need it
	$timerinfo->{command} = $command;

	die("command not supported ($command)")
			unless exists $timer_commands{$command};
	die("half-time flag only makes sense when starting a timer")
			if $timerinfo->{halftime} and $command ne 'START';
	$timer_commands{$command}->($timerinfo);
}


sub setuptimer						# Set up
{
	my ($timername, $timerinfo) = @_;
    my $cfg_file = config_file->read(CONFIG_FILE);
    my $workgroup = $ENV{T3_WORKGROUP} || DEFAULT_WORKGROUP;

    $timerinfo->{timers} = {};

    $timerinfo->{giventimer} = $timername || FALLBACK_TIMER;

    unless ($timerinfo->{user})
	{
		$timerinfo->{user} = $ENV{T3_USER} if exists $ENV{T3_USER};
		die("Invalid user.  Change username or talk to administrator.")
				unless $timerinfo->{user};
	}

    $timerinfo->{tdir} = $cfg_file->lookup($workgroup, TIMERDIR_DIRECTIVE);
	die("don't have a directory for timer files") unless $timerinfo->{tdir};
	die("cannot write to directory $timerinfo->{tdir}")
			unless -d $timerinfo->{tdir} and -w $timerinfo->{tdir};

    $timerinfo->{tfile} = "$timerinfo->{tdir}/$timerinfo->{user}"
            . TIMEFILE_EXT;
    $timerinfo->{hfile} = "$timerinfo->{tdir}/" . HISTFILE;
	print "timer file is $timerinfo->{tfile}\n" if DEBUG >= 1;

	return true;
}


# ------------------------------------------------------------
# Command Procedures
# ------------------------------------------------------------


sub start                   # start a timer
{
	my ($timerinfo) = @_;
	my $timersent = $timerinfo->{giventimer};

	# if new and old are the same, make sure a difference in full/half is
	# being requested, else it's an error
    if ($timersent eq $timerinfo->{curtimer})
	{
		# $halftime indicates if timer is currently running in halftime mode
		# $givenhalftime indicates if halftime is being requested

		my $halftime = $timerinfo->{timers}->{$timerinfo->{curtimer}}->{time}
				=~ m{ 2/ \d+ - $ }x;
		my $givenhalftime = $timerinfo->{halftime};

		die("Timer already started in that mode")
				if ($halftime == $givenhalftime);
	}

	# if currently timing, pause the current timer
	if ($timerinfo->{curtimer})
	{
		$timerinfo->{timers}->{$timerinfo->{curtimer}}->{time} .= time . ',';
		$timerinfo->{timers}->{$timerinfo->{curtimer}}->{posted} = false;
	}

	# if not restarting an existing timer, got to build up some structure
    if (not exists $timerinfo->{timers}->{$timersent})
	{
		foreach my $attrib ( qw<client project phase> )
		{
			$timerinfo->{timers}->{$timersent}->{$attrib}
					= $timerinfo->{$attrib} if exists $timerinfo->{$attrib};
		}
	}

	# add start time, mark unposted
	$timerinfo->{timers}->{$timersent}->{time} .=
			($timerinfo->{halftime} ? "2/" : "") . time . '-';
	$timerinfo->{timers}->{$timersent}->{posted} = false;

	# change current timer marker (in case caller wishes to display something)
	$timerinfo->{curtimer} = $timersent;

	# write the file and get out
	writefile($timerinfo);
	return true;
}


sub pause                   # pause all timers
{
	my ($timerinfo) = @_;

	# make sure pause makes sense
    if (!$timerinfo->{curtimer})
    {
		die("No timer is running");
    }

	# provide end time, mark unposted, clear current timer
    $timerinfo->{timers}->{$timerinfo->{curtimer}}->{time} .= time . ',';
    $timerinfo->{timers}->{$timerinfo->{curtimer}}->{posted} = false;
    $timerinfo->{curtimer} = "";

	# write the file and get out
    writefile($timerinfo);
	return true;
}


sub cancel                   # cancel a timer
{
	my ($timerinfo) = @_;
	my $timersent = $timerinfo->{giventimer};

	# make sure timer to cancel really exists
   	unless (exists $timerinfo->{timers}->{$timersent})
    {
		die("Can't cancel; no such timer.");
    }

	# get rid of timer
	_remove_timer($timerinfo, $timersent);

	# write the file and get out
    writefile($timerinfo);
	return true;
}


sub done                   # done with a timer
{
	my ($timerinfo) = @_;
	my $timersent = $timerinfo->{giventimer};

    unless (exists $timerinfo->{timers}->{$timersent})
    {
		die("No such timer as $timersent");
    }

	# cheat by calling the log command, which does exactly what we need
	log_time($timerinfo);

	# get rid of timer
	_remove_timer($timerinfo, $timersent);

    if ($timerinfo->{curtimer} eq $timersent)
    {
        undef($timerinfo->{curtimer});
    }

    writefile($timerinfo);
	return true;
}


sub log_time
{
	my ($timerinfo) = @_;

	# build arg list for insert_time_log and make sure all are there
	my @insert_args = ();
	foreach my $attrib ( qw<user employee client project phase>,
			qw<tracking date hours comments> )
	{
		die("cannot log to database without attribute $attrib")
				unless exists $timerinfo->{$attrib};
		push @insert_args, $timerinfo->{$attrib};
	}

	# stuff it into the database (this dies if it fails)
	insert_time_log(@insert_args);

	# surprisingly, no need to write the file on this one
	return true;
}


sub list
{
	my ($timerinfo) = @_;

	return true;
}


sub rename                   # new name for a timer
{
	my ($timerinfo) = @_;

    # just a shortcut here
    my $oldname = $timerinfo->{giventimer};
    unless (exists $timerinfo->{timers}->{$oldname})
    {
		die("Can't rename; no such timer.");
    }

    if (not $timerinfo->{newname})
    {
		die("New name not specified");
    }

    my $newname = $timerinfo->{newname};

    # if changing timer name
    if ($newname ne $oldname)
    {
		# can't rename to same name as an existing timer, of course
        if (exists $timerinfo->{timers}->{$newname})
        {
			die("That timer already exists");
        }

		# copy old to new
        $timerinfo->{timers}->{$newname} = $timerinfo->{timers}->{$oldname};
		# delete new
        delete $timerinfo->{timers}->{$oldname};
    }

    # change other parameters
	# (not checking these against database)
    $timerinfo->{timers}->{$newname}->{client} = $timerinfo->{client}
			if $timerinfo->{client};
    $timerinfo->{timers}->{$newname}->{project} = $timerinfo->{project}
			if $timerinfo->{project};
    $timerinfo->{timers}->{$newname}->{phase} = $timerinfo->{phase}
			if $timerinfo->{phase};

	# timer should be marked unposted so changes can go to database
	$timerinfo->{timers}->{$newname}->{posted} = false;

	# switch current timer marker if renaming current timer
    $timerinfo->{curtimer} = $newname if $timerinfo->{curtimer} eq $oldname;

	# write the file and get out
    writefile($timerinfo);
	return true;
}


# ------------------------------------------------------------
# Helper Procedures
# ------------------------------------------------------------


sub t3
{
	$t3 = DataStore->open(DEBUG ? "t3test" : "T3", $ENV{USER})
			unless defined $t3;
	return $t3;
}


sub _remove_timer
{
	my ($timerinfo, $timer_to_remove) = @_;

	# save to history file, get rid of timer, and reset current timer marker
	# if the removed timer is the current one

    save_history($timerinfo, $timerinfo->{command});
    delete $timerinfo->{timers}->{$timer_to_remove};
    $timerinfo->{curtimer} = ""
            if $timerinfo->{curtimer} eq $timer_to_remove;
}


# ------------------------------------------------------------
# File manipulation Procedures
# ------------------------------------------------------------


sub readfile
{
	my ($timerinfo) = @_;

	open(TFILE, $timerinfo->{tfile}) or die("can't read timer file");
	$timerinfo->{curtimer} = "";
	while ( <TFILE> )
	{
		chomp;
		my ($key, $time, $client, $proj, $phase, $posted) = split(/\t/);
		my $curtimer = {};
		$curtimer->{time} = $time;
		$curtimer->{client} = $client;
		$curtimer->{project} = string::upper($proj);
		$curtimer->{phase} = string::upper($phase);
		$curtimer->{posted} = string::upper($posted);
		$timerinfo->{timers}->{$key} = $curtimer;
		$timerinfo->{curtimer} = $key if ($time =~ /-$/);
	}
	close(TFILE);
}


sub writefile
{
	my ($timerinfo) = @_;

	# don't really care whether this succeeds or not
	save_to_db($timerinfo);

	open(TFILE, ">$timerinfo->{tfile}") or die("can't write to timer file");
	foreach my $timername (keys %{$timerinfo->{timers}})
	{
		my $timerstuff = $timerinfo->{timers}->{$timername};
		my $phase = $timerstuff->{phase} ? $timerstuff->{phase} : "";
		print TFILE join("\t",
				$timername, $timerstuff->{time},
				$timerstuff->{client}, $timerstuff->{project},
				$phase, $timerstuff->{posted},
			), "\n";
	}
	close(TFILE);
}


sub save_history
{
	my ($timerinfo, $command) = @_;
	my $timerstuff = $timerinfo->{timers}->{$timerinfo->{giventimer}};

	open(HIST, ">>$timerinfo->{hfile}") or die("couldn't open history file");
	print HIST join("\t",
			$timerinfo->{user}, $ENV{USER}, $command,
			$timerinfo->{giventimer}, $timerstuff->{time},
			$timerstuff->{client}, $timerstuff->{project},
			$timerstuff->{phase},
		), "\n";
	close(HIST);
}


# ------------------------------------------------------------
# Database Procedures for timing
# ------------------------------------------------------------


sub save_to_db
{
	my ($timerinfo) = @_;
	print STDERR "Entered save_to_db\n" if DEBUG >= 4;

	my $posted_timers = &t3->do("
			select t.timer_name
			from {~timer}.timer t, {~t3}.workgroup_user wu
			where t.wuser_id = wu.wuser_id
			and wu.nickname = '$timerinfo->{user}'
	");
	return false unless $posted_timers;

	# change db_timernames to a hash
	my $db_timernames = [];
	while ($posted_timers->next_row())
	{
		push @$db_timernames, $posted_timers->col(0);
	}

	foreach my $timer (keys %{$timerinfo->{timers}})
	{
		print STDERR "Calling db_post_timer for $timer\n" if DEBUG >= 3;
		my $timerstuff = $timerinfo->{timers}->{$timer};
		return false unless db_post_timer($timerinfo->{user}, $timer,
				$timerstuff, $db_timernames);
	}

	foreach my $timer (@$db_timernames)
	{
		print STDERR "Deleting leftover db timer $timer\n" if DEBUG >= 3;
		db_delete_timer($timerinfo->{user}, $timer);
	}

	print STDERR "Leaving save_to_db w/o error\n" if DEBUG >= 4;
	return true;
}


sub db_post_timer
{
	my ($user, $name, $timer, $timernames) = @_;
	print STDERR "Entered db_post_timer, processing $name\n" if DEBUG >= 4;

	my $element_num = aindex(@$timernames, $name);
	# if the name was found in the list ...
	if ( $element_num >= $[ )
	{
		print STDERR "Removing old timer $name from list\n" if DEBUG >= 3;
		# if it hasn't been posted ...
		if (not $timer->{posted})
		{
			# try to delete it from the db
			print STDERR "Deleting old timer $name from db before posting\n"
					if DEBUG >= 2;
			return false unless db_delete_timer($user, $name);
		}
		# remove it from the list
		splice(@$timernames, $element_num, 1);
	}
	else
	{
		# not found in the list, mark it as unposted
		$timer->{posted} = false;
	}

	# if it hasn't been posted ...
	if (not $timer->{posted})
	{
		print STDERR "Posting unposted timer $name\n" if DEBUG >= 2;

		my $client = exists $timer->{client} ? "'$timer->{client}'" : "NULL";
		my $proj = exists $timer->{project} ? "'$timer->{project}'" : "NULL";
		my $phase = exists $timer->{phase} ? "'$timer->{phase}'" : "NULL";
		my $result = &t3->do("
				insert {~timer}.timer
				select wu.wuser_id, '$name', $client, $proj, $phase
				from {~t3}.workgroup_user wu
				where wu.nickname = '$user'
		");
		print STDERR &t3->last_error() and
		return false unless $result and $result->rows_affected() == 1;

		foreach my $chunk (split(',', $timer->{time}))
		{
			my $divisor; $chunk =~ s@^(\d+)/@@ and $divisor = $1;
			$divisor = 1 unless $divisor;

			my ($start_secs, $end_secs) = split('-', $chunk);
			my $start = "'" . strftime("%b %d, %Y %H:%M:%S",
					localtime($start_secs)) . "'";
			my $end = $end_secs ? "'" . strftime("%b %d, %Y %H:%M:%S",
					localtime($end_secs)) . "'" : "NULL";

			my $result = &t3->do("
					insert {~timer}.timer_chunk
					select wu.wuser_id, '$name', $divisor, $start, $end
					from {~t3}.workgroup_user wu
					where wu.nickname = '$user'
			");
			print STDERR &t3->last_error() and
			return false unless $result and $result->rows_affected() == 1;
		}

		# note that timers that are still timing (easy to tell because their
		# time chunks string ends in a dash) are never considered posted
		$timer->{posted} = true unless substr($timer->{time}, -1) eq '-';
	}

	print STDERR "Leaving db_post_timer w/o error\n" if DEBUG >= 4;
	return true;
}


sub db_delete_timer
{
	my ($user, $name) = @_;
	print STDERR "Entered db_delete_timer, timer $name, user $user\n" if DEBUG >= 4;

	my $result = &t3->do("
			delete {~timer}.timer_chunk 
			where timer_name = '$name'
			and exists
			(
				select 1
				from {~t3}.workgroup_user wu
				where wu.wuser_id = {~timer}.timer_chunk.wuser_id
				and wu.nickname = '$user'
			)
	");
	return false unless $result;
	print STDERR "First delete (timer_chunk) finished w/o error\n" if DEBUG >= 4;

	$result = &t3->do("
			delete {~timer}.timer
			where timer_name = '$name'
			and exists
			(
				select 1
				from {~t3}.workgroup_user wu
				where wu.wuser_id = {~timer}.timer.wuser_id
				and wu.nickname = '$user'
			)
	");
	return false unless $result and $result->rows_affected() == 1;

	print STDERR "Leaving db_delete_timer w/o error\n" if DEBUG >= 4;
	return true;
}


# ------------------------------------------------------------
# Database Procedures for Timer data
# ------------------------------------------------------------


sub get_emp_id
{
	my ($user) = @_;

	my $res = &t3->do("
			select e.emp_id
			from {~t3}.workgroup_user wu, {~t3}.person pe, {~timer}.employee e
			where wu.nickname = '$user'
			and wu.person_id = pe.person_id
			and pe.person_id = e.person_id
	");
	die("default client query failed") unless $res and $res->next_row();
	return $res->col(0);
}


sub default_client
{
	my ($emp) = @_;

	my $res = &t3->do("
			select e.def_client
			from {~timer}.employee e
			where e.emp_id = '$emp'
	");
	die("default client query failed") unless $res and $res->next_row();
	return $res->col(0);
}


sub valid_employees
{
	my $res = &t3->do("
			select e.emp_id, pe.first_name, pe.last_name
			from {~timer}.employee e, {~t3}.person pe
			where e.person_id = pe.person_id
			and exists
			(
				select 1
				from {~timer}.client_employee ce
				where e.emp_id = ce.emp_id
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid employees query failed:", &t3->last_error()) unless $res;

	my $emps = {};
	while ($res->next_row())
	{
		$emps->{$res->col(0)} = $res->col(1) . " " . $res->col(2);
	}
	return $emps;
}


sub valid_clients
{
	my ($emp) = @_;

	my $res = &t3->do("
			select c.client_id, c.name
			from {~timer}.client c
			where exists
			(
				select 1
				from {~timer}.employee e, {~timer}.client_employee ce
				where e.emp_id = '$emp'
				and e.emp_id = ce.emp_id
				and c.client_id = ce.client_id
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid clients query failed:", &t3->last_error()) unless $res;

	my $clients = {};
	while ($res->next_row())
	{
		# print STDERR "valid cli: ", $res->col(0), " => ", $res->col(1), "\n";
		$clients->{$res->col(0)} = $res->col(1);
	}
	return $clients;
}


sub valid_projects
{
	my ($emp, $client) = @_;

	my $res = &t3->do("
			select p.proj_id, p.name
			from {~timer}.project p
			where p.client_id = '$client'
			and {&curdate} between p.start_date and p.end_date
			and exists
			(
				select 1
				from {~timer}.employee e, {~timer}.client_employee ce
				where e.emp_id = '$emp'
				and e.emp_id = ce.emp_id
				and p.client_id = ce.client_id
				and
				(
					p.proj_id = ce.proj_id
					or ce.proj_id is NULL
				)
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid projects query failed:", &t3->last_error()) unless $res;

	my $projects = {};
	while ($res->next_row())
	{
		# print STDERR "valid proj: ", $res->col(0), " => ", $res->col(1), "\n";
		$projects->{$res->col(0)} = $res->col(1);
	}
	return $projects;
}


sub proj_requirements
{
	my ($client, $proj, $date) = @_;
	# print STDERR "client: $client, proj: $proj\n";

	my $res = &t3->do("
			select pt.requires_phase, pt.requires_tracking,
					pt.requires_comments
			from {~timer}.project p, {~timer}.project_type pt
			where p.client_id = '$client'
			and p.proj_id = '$proj'
			and '$date' between p.start_date and p.end_date
			and p.project_type = pt.project_type
	");
	die("project requirements query failed:", &t3->last_error())
			unless $res;

	if ($res->next_row())
	{
		return $res->all_cols();
	}
	else
	{
		return (0,0,0);
	}
}


sub phase_list
{
	my $res = &t3->do("
			select ph.phase_id, ph.name
			from {~timer}.phase ph
	");
	die("phase list query failed:", &t3->last_error()) unless $res;

	my $phases = {};
	while ($res->next_row())
	{
		$phases->{$res->col(0)} = $res->col(1);
	}
	return $phases;
}


sub valid_trackings
{
	my ($client) = @_;

	my $res = &t3->do("
			select ct.tracking_code, ct.name
			from {~timer}.client_tracking ct
			where ct.client_id = '$client'
	");
	die("valid trackings query failed:", &t3->last_error()) unless $res;

	my $track = {};
	while ($res->next_row())
	{
		$track->{$res->col(0)} = $res->col(1);
	}
	return $track;
}


sub client_rounding
{
	my ($client) = @_;

	my $res = &t3->do("
			select c.rounding, c.to_nearest
			from {~timer}.client c
			where c.client_id = '$client'
	");
	die("client rounding query failed:", &t3->last_error())
			unless $res and $res->next_row();

	return $res->all_cols();
}


sub this_week_totals
{
=comment
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
=cut
	die("this weeks totals function not yet implemented");
}


sub insert_time_log
{
	my ($user, $emp, $client, $proj, $phase, $tracking, $date,
			$hours, $comments) = @_;

	$emp = "'$emp'";
	$client = "'$client'";
	$proj = "'$proj'";
	$phase = $phase ? "'$phase'" : "NULL";
	$tracking = $tracking ? "'$tracking'" : "NULL";
	$date = "'$date'";
	$comments =~ s/'/''/g;			# handle literal single quotes
	$comments = defined $comments ? "'$comments'" : "NULL";

	my $query = "
			insert {~timer}.time_log
				(	emp_id, client_id, proj_id, phase_id, tracking_code,
					log_date, hours, comments,
					create_user, create_date
				)
			values
			(	$emp, $client, $proj, $phase, $tracking,
				$date, $hours, $comments,
				'$user', {&curdate}
			)
	";

	# print STDERR "$query\n";
	my $result = &t3->do($query);
	die("database error: ", &t3->last_error())
			unless defined $result and $result->rows_affected() == 1;
	return true;
}


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


# ------------------------------------------------------------
# Calculation Procedures
# ------------------------------------------------------------


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
	return ++$mon . "/" . $day . "/" . ($year + 1900);
}
