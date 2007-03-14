###########################################################################
#
# Barefoot::T3::base
#
###########################################################################
#
# This provides basic constants and functions that just about every T3 module will use.  Most of these are
# exported into your namespace whether you like or not, so try to peruse the list carefully before including.
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

use Barefoot;


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


###########################################################################

package Barefoot::T3::base;

### Private ###############################################################

use strict;
use warnings;

use base qw<Exporter>;
our @EXPORT = (
	qw< t3 t3_config t3_username t3_filenames >,
	qw< t3_pipename t3_create_pipe >,
);

use Data::Dumper;
use POSIX qw<mkfifo>;

use Barefoot;
use Barefoot::exception;
use Barefoot::config_file;
use Barefoot::DataStore::Procs;


our $t3;																# DataStore for singleton


# set these up so we won't have to specify them all the time
DataStore->update_or_insert_set_stamps(	insert => { create_user => $ENV{'USER'}, create_date => '{&curdate}' },
										update => { chguser => $ENV{'USER'}, chgdate => '{&curdate}' });


###########################
# Subroutines:
###########################


sub t3
{
	unless (defined $t3)
	{
		my $dstore = DEBUG ? "t3test" : "T3";
		debuggit(2 => "opening datastore", $dstore);
		$t3 = DataStore->open($dstore, $ENV{USER});
	}
	return $t3;
}


sub t3_config
{
	# delegate
    return &T3::config;
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


###########################################################################
#
# This is the base class for T3 modules.  Each module should override the functions to do their own thing.
#
###########################################################################

package T3::Module;

use Moose;

use Carp;
use Date::Format;
use Data::Dumper;

use Barefoot;
use Barefoot::exception;


# public attributes
has user => (isa => 'Str', is => 'ro', required => 1, default => sub { $_[0]->cur_user() });

# private attributes
has _basefile => (is => 'rw', default => '');
has _histfile => (is => 'rw', default => '');

# these following attributes don't need to be defined here, but you have to define them in derived classes
# if you don't, several functions will keel over dead at runtime
#has name => (is => 'ro', default => 'MODCODE');
#has base_file_ext => (is => 'ro', default => '.ext');
#has hist_file => (is => 'ro', default => 'module.history');


use constant TEXT_SEP => "==========\n";


sub _abstract
{
	croak("attempt to call function of abstract base class");
}


sub cur_user
{
	die("Invalid user.  Change username or talk to administrator.") unless exists $ENV{'T3_USER'};
	return $ENV{'T3_USER'};
}


###########################
# This works just like
#
#		values %$thingies
#
# except that it picks out the tags and doesn't return them.  Makes it much easier to loop through thingies
# (timers, todods, etc).
#
sub values
{
	my ($this, $objs) = @_;
	debuggit(5 => "values of", Dumper($objs));
	return map { /^:/ ? () : $objs->{$_} } keys %$objs;
}


sub base_filename
{
	my ($this) = @_;

	# first, if we've figured this stuff out before, just return the cache
	if ($this->{_basefile})
	{
		return $this->{_basefile};
	}

	my $t3dir = T3::config(T3::TIMERDIR_DIRECTIVE);
	die("don't have a directory for timer files") unless $t3dir;
	# TODO: we may not need to be able to write to this directory - can't really say until we parse options!
	#die("cannot write to directory $t3dir") unless -d $t3dir and -w _;

	my $basefile = "$t3dir/" . $this->user . $this->base_file_ext;
	debuggit(2 => "base file is", $basefile);

	# save in cache in case needed again
	$this->{_basefile} = $basefile;

	return $basefile;
}


sub hist_filename
{
	my ($this) = @_;

	# first, if we've figured this stuff out before, just return the cache
	if ($this->{_histfile})
	{
		return $this->{_histfile};
	}

	my $t3dir = T3::config(T3::TIMERDIR_DIRECTIVE);
	die("don't have a directory for timer files") unless $t3dir;
	die("cannot write to directory $t3dir") unless -d $t3dir and -w _;

	my $histfile = "$t3dir/" . $this->hist_file;
	debuggit(2 => "history file is", $histfile);

	# save in cache in case needed again
	$this->{_histfile} = $histfile;

	return $histfile;
}


sub readfile
{
	my ($this, $opts) = @_;
	$opts ||= {};
	debuggit(4 => "base readfile: args module", $this->name, "user", $this->user, "opts", Dumper($opts));

	my $objects = {};

	open(TFILE, $this->base_filename) or die("can't read " . lc($this->name) . " file (" . $this->base_filename . ")");
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

		if ( s/^:(.+?)\t// )
		{
			my $tag = $1;
			my $tag_read = $opts->{'TAGS'}->{$tag};
			if ($tag_read)
			{
				$tag_read->($objects, $_);
				next;
			}
			else
			{
				die("don't know how to read tag line $tag in " . lc($this->name) . " file");
			}
		}

		my $obj = {};
		($this->fields($obj)) = split("\t", $_, -1);
		$objects->{$obj->{'name'}} = $obj;
		$opts->{'FOREACH'}->($objects, $obj) if $opts->{'FOREACH'};
	}
	close(TFILE);

	return $objects;
}


sub writefile
{
	my ($this, $objects, $opts) = @_;
	$opts ||= {};
	debuggit(4 => "base writefile: args module", $this->name, "user", $this->user, "opts", Dumper($opts));
	debuggit(5 => "                objects", Dumper($objects));

	# don't really care whether this succeeds or not
	try
	{
		debuggit(5 => "writefile: in try block");
		# turned off temporarily until this can be fixed
		#this->save_to_db($objects);
	}
	catch
	{
		debuggit(3 => "writefile: returning from catch block with error", $_);
		return;															# from catch block
	};
	debuggit(5 => "writefile: made it past exception block");

	my $tfile = $this->base_filename;
	debuggit(3 => "writefile: going to print to file", $tfile);

	my $backup_rotate = $opts->{'BACKUP_ROTATE'};
	debuggit(4 => "writefile: looping through", $backup_rotate, "backups");
	while ($backup_rotate)
	{
		my $rfile = "$tfile.$backup_rotate";
		my $prev_rfile = --$backup_rotate ? "$tfile.$backup_rotate" : $tfile;
		unlink $rfile if -e $rfile;
		rename $prev_rfile, $rfile if -e $prev_rfile;
	}
	debuggit(5 => "finished rotating backups");

	open(TFILE, ">$tfile") or die("can't write to " . lc($this->name) . " file");
	my %text;
	foreach my $obj ($this->values($objects))
	{
		no warnings 'uninitialized';									# writing undef values to the file is okay

		debuggit(5 => "writing object", $obj->{'name'});
		print TFILE join("\t", $this->fields($obj)), "\n";
		foreach ($this->text_fields)
		{
			$text{"$obj->{'name'}:$_"} = $obj->{$_} if exists $obj->{$_};
		}
	}
	debuggit(5 => "finished writing main records");
	print TFILE TEXT_SEP if %text;
	while (my ($which, $text) = each %text)
	{
		print TFILE "$which:\n", "$text\n", TEXT_SEP;
	}
	close(TFILE);
}


sub save_history
{
	my ($this, $command, $object) = @_;
	debuggit(5 => "entering save_history function");

	my $hfile = $this->hist_filename;
	debuggit(3 => "going to print to file", $hfile);
	open(HFILE, ">>$hfile") or die("can't write to history file");

	print HFILE join("\t", $this->cur_user, time2str("%L/%e/%Y %l:%M%P", time()),
			$command, $this->user, $this->fields($object)), "\n";

	close(HFILE);
}


sub save_to_db
{
	# this one may or may not be overriden, so don't croak here
	return 1;
}


###########################
# Methods that MUST be overriden:
###########################


# THE fields() METHOD
#
# These tend to look very esoteric, but they just encapsulate a single place where your modules "things"
# (timers, todo items, etc) can be broken into their various components.  By having this function, the fields
# will always be in the same order, and since the method are marked lvalue and return slices, you can assign to
# it too.
#
# (Warning! default context for lvalue subs in Perl is scalar, so this is
# not going to work:
#
#		$mod->fields($todo) = split("\t");
#
# it ought to give you a warning.  proper syntax is this:
#
#		($mod->fields($todo)) = split("\t");
#
# don't shoot us; we didn't make the rules.)
#
sub fields																# when you override, you MUST put ": lvalue" here
{
	_abstract();
}


sub text_fields
{
	_abstract();
}



###########################
# Return a true value:
###########################

1;
