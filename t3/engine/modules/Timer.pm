# these are the requests that make up the Timer module

package TimerModule;

use strict;

use Barefoot::base;
use Barefoot::T3::base;
use Barefoot::T3::Server;
use Barefoot::T3::Timer qw<calc_time>;

T3::Server::register_request(TIMER_LIST => \&list_timers);


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
		$timer->{time} = $pretty_time;

		if (exists $opts->{details} and $opts->{details} eq "yes")
		{
			print join("\t", timer_fields($timer)), "\n";
		}
		else
		{
			T3::debug(3, "going to print: //"
					. join("\t", $timer->{name}, $pretty_time). "//");
			print join("\t", $timer->{name}, $timer->{time}), "\n";
		}
	}
	close(TMR);
}


###########################
# Return a true value:
###########################

1;
