#! /usr/local/bin/perl

###########################################################################
#
# Barefoot::T3::base
#
###########################################################################
#
# This provides basic constants and functions that just about every T3
# module will use.  Most of these are exported into your namespace whether
# you like or not, so try to peruse the list carefully before including.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2003 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
#
###########################################################################


###########################################################################
#
# constants are placed in a separate package, so they can be accessed thus:
#
#	my $reqfile = T3::REQUEST_FILE;
#
###########################################################################

package T3;

use strict;
use warnings;

use Barefoot::base;


# config file and directives for same

use constant CONFIG_FILE => '/etc/t3.conf';

use constant DBSERVER_DIRECTIVE => 'DBServer';
use constant DATABASE_DIRECTIVE => 'Database';
use constant TIMERDIR_DIRECTIVE => 'TimerDir';
use constant REQUESTDIR_DIRECTIVE => 'RequestDir';
use constant MODULEDIR_DIRECTIVE => 'ModulesDir';
use constant WREPORTDIR_DIRECTIVE => 'WebReportsDir';


# files for use by client/server routines

use constant REQUEST_FILE => 't3.request';
use constant OUTPUT_FILE => 't3.output.';


# workgroup names

use constant DEFAULT_WORKGROUP => 'Barefoot';
use constant TEST_WORKGROUP => 'TestCompany';


# tag names
# tags are special members of a list of T3 objects (e.g., timers, todo tasks)
# they are denoted by beginning with a colon
# (this is consequently illegal for the "normal" names of T3 objects)

use constant CURRENT_TIMER => ':CURRENT';


# need this for getting proper values out of config file (below)
our $workgroup = DEBUG ? T3::TEST_WORKGROUP
		: $ENV{T3_WORKGROUP} || T3::DEFAULT_WORKGROUP;

# let's read in the config file here and let people use t3_config
# to get various and sundry parameters out of it
# (saves having to read the config file in several times)
our $cfg_file = config_file->read(T3::CONFIG_FILE);


###########################
# Subroutines:
###########################


sub config
{
	# just return lookup of current workgroup and all args
    return $cfg_file->lookup($workgroup, @_);
}


sub debug
{
	if (Barefoot::DEBUG)
	{
		my $level = 2;							# default in case not specified
		my $msg;
		if (@_ > 1)
		{
			($level, $msg) = @_;
		}
		else
		{
			($msg) = @_;
		}

		print STDERR "$0 ($$): $msg at ", scalar(localtime(time())), "\n"
				if Barefoot::DEBUG >= $level;
	}
}


BEGIN
{
	# cache storage
	my (%basefiles, %histfiles);

	# file extensions
	my %base_file_ext =
	(
		TIMER	=>	'.timer',
		TODO	=>	'.todo',
	);
	my %hist_file =
	(
		TIMER	=>	'timer.history',
		TODO	=>	'todo.history',
	);

	sub base_filename
	{
		my ($module, $user) = @_;

		# first, if we've figured this stuff out before, just return the cache
		if (exists $basefiles{$user}
				and exists $basefiles{$user}->{$module})
		{
			return $basefiles{$user}->{$module};
		}

		# double check validity of which file
		# (this indicates a logic error)
		die("don't know extension for module $module")
				unless exists $base_file_ext{$module};

		my $t3dir = T3::config(T3::TIMERDIR_DIRECTIVE);
		die("don't have a directory for timer files") unless $t3dir;
		die("cannot write to directory $t3dir") unless -d $t3dir and -w _;

		my $basefile = "$t3dir/$user" . $base_file_ext{$module};
		print "$module base file is $basefile\n" if DEBUG >= 2;

		# save in cache in case needed again
		$basefiles{$user}->{$module} = $basefile;

		return $basefile;
	}

	sub hist_filename
	{
		my ($module) = @_;

		# first, if we've figured this stuff out before, just return the cache
		if (exists $histfiles{$module})
		{
			return $histfiles{$module};
		}

		# double check validity of which file
		# (this indicates a logic error)
		die("don't know history file for module $module")
				unless exists $hist_file{$module};

		my $t3dir = T3::config(T3::TIMERDIR_DIRECTIVE);
		die("don't have a directory for timer files") unless $t3dir;
		die("cannot write to directory $t3dir") unless -d $t3dir and -w _;

		my $histfile = "$t3dir/" . $hist_file{$module};
		print "$module history file is $histfile\n" if DEBUG >= 2;

		# save in cache in case needed again
		$histfiles{$module} = $histfile;

		return $histfile;
	}
}


###########################################################################

package Barefoot::T3::base;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<t3 t3_config t3_username t3_filenames t3_pipename t3_create_pipe timer_fields todo_fields>;

use POSIX qw<mkfifo>;

use Barefoot::base;
use Barefoot::config_file;


our $t3;									# DataStore for singleton


###########################
# Subroutines:
###########################


sub t3
{
	unless (defined $t3)
	{
		my $dstore = DEBUG ? "t3test" : "T3";
		print STDERR "opening datastore $dstore\n" if DEBUG >= 2;
		$t3 = DataStore->open($dstore, $ENV{USER})
	}
	return $t3;
}


sub t3_config
{
	# delegate
    return &T3::config;
}


sub t3_username
{
	die("Invalid user.  Change username or talk to administrator.")
			unless exists $ENV{T3_USER};
	return $ENV{T3_USER};
}


sub t3_filenames
{
	my ($module, $user) = @_;

	return (T3::base_filename($module, $user),
			T3::hist_filename($module, $user));
}


my $pipe_dir = Barefoot::T3::base::t3_config(T3::REQUESTDIR_DIRECTIVE);
sub t3_pipename
{
	return $pipe_dir . "/" . $_[0];
}

sub t3_create_pipe
{
	my $pipe_file = t3_pipename($_[0]);

	# save old umask and set it to something reasonable
	# our pipe needs to be open to at least group access
	my $old_umask = umask 0002;

	unlink($pipe_file) if -e $pipe_file;
	T3::debug(4, -e $pipe_file ? "pipe exists" : "pipe is gone");
	if (mkfifo($pipe_file, 0666))
	{
		umask $old_umask;
		return $pipe_file;
	}
	else
	{
		umask $old_umask;
		return undef;
	}
}


# THE *_fields() SUBS
#
# these looks very esoteric, but they just encapsulate a single place where
# a timer, todo item, etc can be broken into their various components.
# by having this function, the fields will always be in the same order,
# and since the subs are marked lvalue and return slices, you can assign
# to it too.
# (Warning! default context for lvalue subs in Perl is scalar, so this is
# not going to work:
#
#		todo_fields($todo) = split("\t");
#
# it ought to give you a warning.  proper syntax is this:
#
#		(todo_fields($todo)) = split("\t");
#
# don't shoot us; we didn't make the rules.)

sub timer_fields : lvalue
{
	@{$_[0]}{ qw<name time client project phase posted todo_link> };
}

sub todo_fields : lvalue
{
	@{$_[0]}{ qw<name descr client project due> };
}


###########################
# Return a true value:
###########################

1;
