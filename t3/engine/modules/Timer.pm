# these are the requests that make up the Timer module

package TimerModule;

use strict;

use Barefoot::base;
use Barefoot::exception;

use Barefoot::T3::base;
use Barefoot::T3::Server;
use Barefoot::T3::Timer qw<calc_time calc_date>;

use Barefoot::T3Timer qw<do_timer_command readfile>;


T3::Server::register_request(TIMER_LIST => \&list_timers);
T3::Server::register_request(START_TIMER => \&start_timer);
T3::Server::register_request(PAUSE_TIMERS => \&pause_timers);


###########################
# Subroutines:
###########################


sub list_timers
{
	my $opts = shift;

	# don't care about history file name
	my ($timer_file, undef) = t3_filenames("timer", $opts->{user});

	my $success = open(TMR, $timer_file);
	unless ($success)
	{
		print "ERROR: can't open timer file for user $opts->{user}\n";
		print "TIMER FILE: $timer_file\n" if DEBUG >= 2;
		return;
	}
	while ( <TMR> )
	{
		next if exists $opts->{timer} and not /^$opts->{timer}\t/;

		chomp;
		my $timer = {};

		(timer_fields($timer)) = split("\t", $_, -1);
		my $total_time = calc_time($timer->{time});
		my $pretty_time = sprintf("%d:%02d", int($total_time / 60),
				$total_time % 60);
		my $date = calc_date($timer->{time});
		my $current = $timer->{time} =~ /-$/ ? 1 : 0;
		$timer->{time} = $pretty_time;

		if (exists $opts->{details} and $opts->{details} eq "yes")
		{
			T3::debug(3, "going to print date $date");
			print join("\t", timer_fields($timer), $date, $current), "\n";
		}
		else
		{
			T3::debug(3, "going to print: //"
					. join("\t", $timer->{name}, $pretty_time). "//");
			print join("\t", $timer->{name}, $timer->{time}, $current), "\n";
		}
	}
	close(TMR);
}


sub start_timer
{
	my $opts = shift;

	my $timerinfo = {};
	# don't care about history file name
	($timerinfo->{tfile}, undef) = t3_filenames("timer", $opts->{user});

	# get timers (they accumulate in $timerinfo->{timers})
	readfile($timerinfo);

	try
	{
		$timerinfo->{giventimer} = $opts->{timer};
		do_timer_command('START', $timerinfo);
		print "TIMER STARTED\n";
	}
	catch
	{
		print "ERROR:$_\n";
	};
}


sub pause_timers
{
	my $opts = shift;

	my $timerinfo = {};
	# don't care about history file name
	($timerinfo->{tfile}, undef) = t3_filenames("timer", $opts->{user});

	# get timers (they accumulate in $timerinfo->{timers})
	readfile($timerinfo);

	try
	{
		do_timer_command('PAUSE', $timerinfo);
		print "TIMERS PAUSED\n";
	}
	catch
	{
		print "ERROR:$_\n";
	};
}


###########################
# Return a true value:
###########################

1;
