#! /usr/local/bin/perl

###########################################################################
#
# Barefoot::T3::Todo
#
###########################################################################
#
# Some general functions that are specific to the todo module of Tracker.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2006 Barefoot Software, Copyright (c) 2006 ThinkGeek
#
###########################################################################

package T3::Module::Todo;

### Private ###############################################################

use Moose;

use Data::Dumper;

use Barefoot;
use Barefoot::DataStore;
use Barefoot::DataStore::Procs;

use Barefoot::T3::base;
use Barefoot::T3::db_get qw< one_datum get_emp_id >;


extends q<T3::Module>;


has name => (is => 'ro', default => 'TODO');
has base_file_ext => (is => 'ro', default => '.todo');
has hist_file => (is => 'ro', default => 'todo.history');


###########################
# Helper Methods
###########################


###########################
# Methods
###########################


sub fields : lvalue
{
	my ($this, $object) = @_;
	@{$object}{qw< name client project due posted completed queue >};
}


sub text_fields
{
	return qw< precis description >;
}


sub save_to_db
{
return;
	my ($this, $user, $tasks) = @_;
	debuggit(5 => "Entered todo::save_to_db");

	# if user is MASTER, this is a tracked task
	# also emp will be NULL, so we need to figure this out
	my $is_master = $user eq 'MASTER';

	# we'll need this for most queries
	my $emp = $is_master ? undef : get_emp_id($user);

	# check for unposted cancellations
	if (my $cancelled = $tasks->{':CANCELLED'})
	{
		foreach my $task (keys %$cancelled)
		{
			debuggit(3 => "task", $task, "for user", $user, "cancelled but never posted; removing from DB");

			my $res = &t3->do(q{
				delete from {@task}
				where emp_id = {emp}
				and name = {name}
				and completed is NULL
			},
				emp => $emp, name => $task,
			);
			die("cannot remove from db: " . &t3->last_error) unless $res and $res->rows_affected() == 1;

			delete $tasks->{':CANCELLED'}->{$task};
		}

		# the unless is probably redundant, but paranoia is occasionally useful
		delete $tasks->{':CANCELLED'} unless %{ $tasks->{':CANCELLED'} };
	}

	# check for unposted adds/changes
	foreach my $task ($this->values($tasks))
	{
		if (not $task->{'posted'})
		{
			debuggit(3 => "task", $task->{'name'}, "for user", $user, "not posted; saving to DB");

			my $res = &t3->update_or_insert('{@task}' => q{ where emp_id = {emp_id} and name = {name}
						and completed is NULL },
				{
					name		=>	$task->{'name'},
					title		=>	$task->{'title'},
					emp_id		=>	$emp,
					client_id	=>	$task->{'client'},
					proj_id		=>	$task->{'project'},
					description	=>	'',
					tracked		=>	$is_master,
					due			=>	$task->{'due'},
					completed	=>	undef,
				},
			);
			die("cannot save to db: " . &t3->last_error) unless $res and $res->rows_affected() == 1;

			$task->{'posted'} = 1;
		}
	}
}


###########################
# Return a true value:
###########################

1;
