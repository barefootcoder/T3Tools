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
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2007 Barefoot Software, Copyright (c) 2004-2007 ThinkGeek
#
###########################################################################

package Barefoot::T3::Timer;

### Private ###############################################################

use strict;
use warnings;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw< calc_time calc_date test_connection >;

use Date::Parse;
use Data::Dumper;
use Date::Format;

use Barefoot;
use Barefoot::range;
use Barefoot::exception;

use Barefoot::T3::base;


###########################
# Helper Procedures
###########################


###########################
# Subroutines:
###########################



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
	if ($line and $line =~ /(\d+),$/)									# ends in a comma, must be paused
	{
		$seconds = $1;
	}
	else																# current or no time given
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


our $connected;

sub test_connection
{
	debuggit(5 => "Entered test_connection");

	if (defined $connected)
	{
		# presumably, this means that we've been here before
		# let's just save time and return what we found out last time
		debuggit(4 => "Leaving test_connection w/ cached value", $connected);
		return $connected;
	}

	$connected = eval { &t3->ping() };
	debuggit(4 => $connected ? "Leaving test_connection w/o error"
			: "test_connection got error: " . (defined $connected ? &t3->last_error() : $@));

	return $connected;
}


sub save_to_db
{
	my ($user, $timers) = @_;
	debuggit(5 => "Entered timer::save_to_db");

	# get the workgroup user ID because just about every query needs that
	my $wuser_data = &t3->load_table(q{ select wuser_id from {@workgroup_user} where nickname = {user} }, user => $user);
	# sneaky way to quickly get a datum: 1st col of 1st row of "entire" table
	my $wuser_id = $wuser_data->[0]->[0];
	debuggit(2 => "got workgroup user id", $wuser_id);

	my $posted_timers = &t3->do(q{
		select t.timer_name
		from {@timer} t
		where t.wuser_id = {wuser_id}
	},
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

		debuggit(3 => "Calling db_post_timer for", $tname);
		return false unless db_post_timer($wuser_id, $tname, $timer, $db_timernames);
	}

	while (my $tname = each %$db_timernames)
	{
		debuggit(3 => "Deleting leftover db timer", $tname);
		db_delete_timer($wuser_id, $tname);
	}

	debuggit(5 => "Leaving save_to_db w/o error");
	return true;
}


sub db_post_timer
{
	my ($wuser_id, $tname, $timer, $timernames) = @_;
	debuggit(5 => "Entered db_post_timer, processing", $tname);

	# if the name was found in the list ...
	if ( exists $timernames->{$tname} )
	{
		debuggit(3 => "Removing old timer", $tname, "from list");
		# if it hasn't been posted ...
		if (not $timer->{'posted'})
		{
			# try to delete it from the db
			debuggit(2 => "Deleting old timer", $tname, "from db before posting");
			return false unless db_delete_timer($wuser_id, $tname);
		}
		# remove it from the list
		delete $timernames->{$tname};
	}
	else
	{
		# not found in the list, mark it as unposted
		$timer->{'posted'} = false;
	}

	# if it hasn't been posted ...
	if (not $timer->{'posted'})
	{
		debuggit(2 => "Posting unposted timer", $tname);

		my $result = &t3->do(q{ insert into {@timer} values ???  },
			{
				wuser_id	=>	$wuser_id,
				timer_name	=>	$tname,
				client_id	=>	$timer->{client},
				proj_id		=>	$timer->{project},
				phase_id	=>	$timer->{phase},
			},
		);
		print STDERR &t3->last_error() and return false unless $result and $result->rows_affected() == 1;

		foreach my $chunk (split(',', $timer->{time}))
		{
			my $success = $chunk =~ s@^(\d+)/@@;
			my $divisor = $success ? $1 : 1;
			debuggit(2 => "post_timer: chunk is", $chunk, "divisor is", $divisor);

			my ($start_secs, $end_secs) = split('-', $chunk);
			my $start = time2str("%b %d, %Y %H:%M:%S", $start_secs);
			my $end = $end_secs ? time2str("%b %d, %Y %H:%M:%S", $end_secs) : undef;

			my $result = &t3->do(q{ insert into {@timer_chunk} values ??? },
				{
					wuser_id	=>	$wuser_id,
					timer_name	=>	$tname,
					divisor		=>	$divisor,
					start_time	=>	$start,
					end_time	=>	$end,
				}
			);
			print STDERR &t3->last_error() and return false unless $result and $result->rows_affected() == 1;
		}

		# note that timers that are still timing (easy to tell because their
		# time chunks string ends in a dash) are never considered posted
		$timer->{'posted'} = true unless substr($timer->{time}, -1) eq '-';
	}

	debuggit(5 => "Leaving db_post_timer w/o error");
	return true;
}


sub db_delete_timer
{
	my ($wuser_id, $tname) = @_;
	debuggit(4 => "Entered db_delete_timer: timer", $tname, ", user", $wuser_id);

	my $result = &t3->do(q{
		delete from {@timer_chunk}
		where wuser_id = {wuser_id}
		and timer_name = {timer_name}
	},
		wuser_id => $wuser_id, timer_name => $tname,
	);
	return false unless $result;
	debuggit(5 => "First delete (timer_chunk) finished w/o error");

	$result = &t3->do(q{
		delete from {@timer}
		where wuser_id = {wuser_id}
		and timer_name = {timer_name}
	},
		wuser_id => $wuser_id, timer_name => $tname,
	);
	return false unless $result and $result->rows_affected() == 1;

	debuggit(5 => "Leaving db_delete_timer w/o error");
	return true;
}


###########################################################################
#
# The timer module.
#
###########################################################################

package T3::Module::Timer;

use Moose;

use Storable qw< dclone >;

use Barefoot;
use Barefoot::T3::base;


extends q<T3::Module>;


has name => (is => 'ro', default => 'TIMER');
has base_file_ext => (is => 'ro', default => '.timer');
has hist_file => (is => 'ro', default => 'timer.history');


# Timer command map
our %timer_commands =
(
	START		=>	\&start,
	PAUSE		=>	\&pause,
	CANCEL		=>	\&cancel,
	DONE		=>	\&done,
	LIST		=>	\&list,
	RENAME		=>	\&rename,
	ANNOTATE	=>	\&add_comment,
	LOG			=>	\&log_time,
	COPYINFO	=>	\&copy_info,
);


use constant FALLBACK_TIMER => 'default';


###########################
# Helper Methods
###########################


sub _remove_timer
{
	my ($this, $command, $timers, $timer_to_remove) = @_;
	debuggit(5 => "entering _remove_timer");

	# save to history file, get rid of timer, and reset current timer marker if the removed timer is the
	# current one

    my $del_timer = delete $timers->{$timer_to_remove};
    $this->save_history($command, $del_timer);

    if (exists $timers->{T3::CURRENT_TIMER} and $timers->{T3::CURRENT_TIMER} eq $timer_to_remove)
    {
        delete $timers->{T3::CURRENT_TIMER};
    }
}


sub _insert_time_log
{
	my ($user, $emp, $client, $proj, $phase, $tracking, $date, $hours, $comments) = @_;

	my $result = &t3->do(q{ insert into {@time_log} values ??? },
		{
			emp_id			=>	$emp,
			client_id		=>	$client,
			proj_id			=>	$proj,
			phase_id		=>	$phase,
			tracking_code	=>	$tracking,
			log_date		=>	$date,
			hours			=>	$hours,
			comments		=>	$comments,
			create_user		=>	$user,
			create_date		=>	'{&curdate}',
		},
	);
	die("database error: ", &t3->last_error()) unless defined $result and $result->rows_affected() == 1;
	return true;
}


###########################
# Methods
###########################


sub fields : lvalue
{
	my ($this, $object) = @_;
	@{$object}{ qw<name time client project phase posted todo_link> };
}


sub text_fields
{
	return qw< comments >;
}

sub save_to_db
{
	# waiting to implement this one
	return 1;
}


sub setup_params
{
	my ($this, $timername, $parminfo, $timers) = @_;

    $parminfo->{'timer'} = $timername || FALLBACK_TIMER;
	$parminfo->{'user'} ||= $this->user;

	# try to find a more reasonable default timer
	if ($parminfo->{'timer'} eq FALLBACK_TIMER)
	{
		if ($timers->{T3::CURRENT_TIMER})
		{
			# if there's a current timer, use that
			$parminfo->{'timer'} = $timers->{T3::CURRENT_TIMER};
		}
		elsif (keys %$timers == 1)
		{
			# if there's only 1 timer, use that
			# note: when each is called in a scalar context (such as below),
			# it returns the "next" key (in this case, there's only 1 key)
			$parminfo->{'timer'} = each %$timers;
		}
		# if none of those work, you're stuck with FALLBACK_TIMER
	}
}


sub timer_command
{
	my ($this, $command, $opts, $timers) = @_;
	debuggit(4 => "in timer_command with", $command);

	die("command not supported ($command)") unless exists $timer_commands{$command};
	die("half-time flag only makes sense when starting a timer") if $opts->{'halftime'} and $command ne 'START';

	# run command
	# if there is an error, it will throw an exception
	# return value of command indicates whether or not it is necessary to save data (not all commands modify
	# the timer list)
	if ($timer_commands{$command}->($this, $opts, $timers))
	{
		debuggit(5 => "about to write file");
		$this->writefile($timers, { BACKUP_ROTATE => $opts->{'backup_rotate'} });
		debuggit(5 => "back from writing file");
	}
}


###########################
# Command Procedures
###########################


sub start																# start a timer
{
	my ($this, $opts, $timers) = @_;
	my $timersent = $opts->{'timer'};
	debuggit(3 => "start: going to start timer", $timersent);

	# figure out current timer (if any)
	my $curtimer = $timers->{T3::CURRENT_TIMER} || "";
	debuggit(2 => "start: current timer is", $curtimer);

	# check for illegal characters in names
	die("Illegal character(s) in timer name") if $timersent =~ / / or $timersent =~ /:/;

	# if new and old are the same, make sure a difference in full/half is
	# being requested, else it's an error
    if ($timersent eq $curtimer)
	{
		# $halftime indicates if timer is currently running in halftime mode
		# $givenhalftime indicates if halftime is being requested

		my $halftime = $timers->{$curtimer}->{time} =~ m{ 2/ \d+ - $ }x;
		my $givenhalftime = $opts->{halftime} || 0;

		if ($halftime == $givenhalftime)
		{
			debuggit(4 => "start error; dying");
			die("Timer already started in that mode");
		}
	}

	# if currently timing, pause the current timer
	if ($curtimer)
	{
		debuggit(4 => "going to pause current timer");
		$timers->{$curtimer}->{time} .= time . ',';
		$timers->{$curtimer}->{'posted'} = false;
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
	$timers->{$timersent}->{time} .= ($opts->{halftime} ? "2/" : "") . time . '-';
	$timers->{$timersent}->{'posted'} = false;

	# change current timer marker (in case caller wishes to display something)
	$timers->{T3::CURRENT_TIMER} = $timersent;

	# need to write the file
	return true;
}


sub pause																# pause all timers
{
	my ($this, $opts, $timers) = @_;

	# make sure pause makes sense
    my $curtimer = $timers->{T3::CURRENT_TIMER};
    if (!$curtimer)
    {
		die("No timer is running");
    }

	# provide end time, mark unposted, clear current timer
    $timers->{$curtimer}->{time} .= time . ',';
    $timers->{$curtimer}->{'posted'} = false;
    delete $timers->{T3::CURRENT_TIMER};

	# need to write the file
	return true;
}


sub cancel																# cancel a timer
{
	my ($this, $opts, $timers) = @_;
	my $timersent = $opts->{'timer'};
	debuggit(2 => "cancelling timer", $timersent);

	# make sure timer to cancel really exists
   	unless (exists $timers->{$timersent})
    {
		die("Can't cancel; no such timer");
    }

	# get rid of timer
	$this->_remove_timer(CANCEL => $timers, $timersent);

	# need to write the file
	return true;
}


sub done																# done with a timer
{
	my ($this, $opts, $timers) = @_;
	my $timersent = $opts->{'timer'};
	debuggit(5 => "entering done function");

    unless (exists $timers->{$timersent})
    {
		die("No such timer as $timersent");
    }

	# cheat by calling the log command, which does exactly what we need
	$this->log_time($opts, $timers);
	debuggit(5 => "logged time, about to call _remove_timer");

	# get rid of timer
	$this->_remove_timer(DONE => $timers, $timersent);

	# need to write the file
	return true;
}


sub log_time															# log time not connected to a timer
{
	my ($this, $opts, $timers) = @_;

	# build arg list for _insert_time_log and make sure all are there
	my @insert_args = ();
	foreach my $attrib ( qw<user employee client project phase tracking date hours comments> )
	{
		die("cannot log to database without attribute $attrib") unless exists $opts->{$attrib};
		push @insert_args, $opts->{$attrib};
	}

	# stuff it into the database (this dies if it fails)
	_insert_time_log(@insert_args);

	# surprisingly, no need to write the file on this one
	return false;
}


sub list
{
	my ($this, $opts, $timers) = @_;

	# nothing to do, and no need to write the file
	return false;
}


sub rename																# new name for a timer
{
	my ($this, $opts, $timers) = @_;

	# just a shortcut here
	my $oldname = $opts->{'timer'};
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
		# delete old
		delete $timers->{$oldname};
	}

	# change other parameters
	# (not checking these against database)
	foreach (qw< client project phase >)
	{
		$timers->{$newname}->{$_} = $opts->{$_} if $opts->{$_};
	}

	# timer should be marked unposted so changes can go to database
	$timers->{$newname}->{'posted'} = false;

	# switch current timer marker if renaming current timer
	$timers->{T3::CURRENT_TIMER} = $newname
			if exists $timers->{T3::CURRENT_TIMER} and $timers->{T3::CURRENT_TIMER} eq $oldname;

	# need to write the file
	return true;
}


sub add_comment															# add a comment to (aka annotate) a timer
{
	my ($this, $opts, $timers) = @_;
	my $timersent = $opts->{'timer'};

	# make sure timer to annotate really exists
   	unless (exists $timers->{$timersent})
    {
		die("Can't annotate; no such timer");
    }

	$timers->{$timersent}->{'comments'} = $opts->{'comments'};
	$timers->{$timersent}->{'posted'} = false;

	# need to write the file
	return true;
}


sub copy_info															# copy a timer
{
	my ($this, $opts, $timers) = @_;
	debuggit(2 => "trying to copy info", $opts->{'timer'}, "=>", $opts->{'newtimer'});

	# just a shortcut here
	my $source = $opts->{'timer'};
	unless (exists $timers->{$source})
	{
		die("Can't copy; no such timer");
	}

	if (not $opts->{newtimer})
	{
		die("New name not specified");
	}

	my $dest = $opts->{newtimer};

	# can't copy to same name as an existing timer, of course
	if (exists $timers->{$dest})
	{
		die("That timer already exists");
	}

	# copy old to new
	$timers->{$dest} = dclone($timers->{$source});
	# change name attribute
	$timers->{$dest}->{name} = $dest;
	# remove the actual time
	$timers->{$dest}->{time} = '';

	# allow command-line overrides
	foreach (qw< client project phase >)
	{
		$timers->{$dest}->{$_} = $opts->{$_} if $opts->{$_};
	}

	# timer should be marked unposted so changes can go to database
	$timers->{$dest}->{'posted'} = false;

	# need to write the file
	return true;
}


###########################
# Return a true value:
###########################

1;
