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
# Copyright (c) 2002-2006 Barefoot Software, Copyright (c) 2004-2006 ThinkGeek
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
our $workgroup = DEBUG ? T3::TEST_WORKGROUP : $ENV{T3_WORKGROUP} || T3::DEFAULT_WORKGROUP;

# let's read in the config file here and let people use t3_config to get various and sundry parameters out of
# it (saves having to read the config file in several times)
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

		print STDERR "$0 ($$): $msg at ", scalar(localtime(time())), "\n" if Barefoot::DEBUG >= $level;
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
use warnings;

use base qw<Exporter>;
our @EXPORT = (
	qw< t3 t3_config t3_username >,
	qw< t3_filenames t3_readfile t3_writefile t3_pipename t3_create_pipe >,
	qw< timer_fields todo_fields >,
);

use Data::Dumper;
use POSIX qw<mkfifo>;

use Barefoot::base;
use Barefoot::exception;
use Barefoot::config_file;


use constant TEXT_SEP => "==========\n";


our $t3;									# DataStore for singleton

our %field_func =
(
	TIMER		=>	\&timer_fields,
	TODO		=>	\&todo_fields,
);

our %text_fields =
(
	TIMER		=>	{
						comments	=>	1,
					},
	TODO		=>	{
						description	=>	1,
					},
);


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


sub t3_readfile
{
	my ($module, $user, $opts) = @_;
	$opts ||= {};
	print STDERR "t3_readfile: args module $module, user $user, opts ", Dumper($opts) if DEBUG >= 4;

	my $objects = {};

	open(TFILE, T3::base_filename($module, $user)) or die("can't read \L$module\E file");
	LINE: while ( <TFILE> )
	{
		if ($_ eq TEXT_SEP)
		{
			local $/ = "\n" . TEXT_SEP;
			while ( <TFILE> )
			{
				chomp;
				if ( s/^ (.*?) \n //x)
				{
					my ($name, $field) = split(':', $1);
					s/ \s* \n \s* / /x;
					$objects->{$name}->{$field} = $_;
				}
				else
				{
					die("illegal text line in todo file");
				}
			}
			last LINE;
		}

		chomp;
		my $obj = {};
		($field_func{$module}->($obj)) = split("\t", $_, -1);
		$objects->{$obj->{'name'}} = $obj;
		$opts->{'FOREACH'}->($objects, $obj) if $opts->{'FOREACH'};
	}
	close(TFILE);

	return $objects;
}


sub t3_writefile
{
	my ($module, $user, $objects, $opts) = @_;
	$opts ||= {};
	print STDERR "t3_writefile: args module $module, user $user, opts ", Dumper($opts) if DEBUG >= 4;

	# don't really care whether this succeeds or not
	try
	{
		print STDERR "t3_writefile: in try block\n" if DEBUG >= 5;
		# turned off temporarily until this can be fixed
		#save_to_db($user, $timers);
	}
	catch
	{
		print STDERR "t3_writefile: returning from catch block\n" if DEBUG >= 5;
		return;															# from catch block
	};
	print STDERR "t3_writefile: made it past exception block\n" if DEBUG >= 5;

	my $tfile = T3::base_filename($module => $user);
	print STDERR "t3_writefile: going to print to file $tfile\n" if DEBUG >= 3;

	my $backup_rotate = $opts->{'BACKUP_ROTATE'};
	while ($backup_rotate)
	{
		my $rfile = "$tfile.$backup_rotate";
		my $prev_rfile = --$backup_rotate ? "$tfile.$backup_rotate" : $tfile;
		unlink $rfile if -e $rfile;
		rename $prev_rfile, $rfile if -e $prev_rfile;
	}

	open(TFILE, ">$tfile") or die("can't write to \L$module\E file");
	my %text;
	while (my ($name, $obj) = each %$objects)
	{
		# ignore tags
		next if substr($name, 0, 1) eq ':';

		print TFILE join("\t", $field_func{$module}->($obj)), "\n";
		foreach (keys %{$text_fields{$module}})
		{
			$text{"$name:$_"} = $obj->{$_} if exists $obj->{$_};
		}
	}
	print TFILE TEXT_SEP if %text;
	while (my ($which, $text) = each %text)
	{
		print TFILE "$which:\n", "$text\n", TEXT_SEP;
	}
	close(TFILE);
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
	@{$_[0]}{ qw<name title client project due> };
}


###########################
# Return a true value:
###########################

1;
