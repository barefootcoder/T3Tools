#! /usr/local/bin/perl -w

# For CVS:
# $Date$
#
# $Id$
# $Revision$

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
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
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


# config file and directives for same

use constant CONFIG_FILE => '/etc/t3.conf';

use constant DBSERVER_DIRECTIVE => 'DBServer';
use constant DATABASE_DIRECTIVE => 'Database';
use constant TIMERDIR_DIRECTIVE => 'TimerDir';
use constant REQUESTDIR_DIRECTIVE => 'RequestDir';
use constant MODULEDIR_DIRECTIVE => 'ModulesDir';


# files for use by client/server routines

use constant REQUEST_FILE => 't3.request';
use constant OUTPUT_FILE => 't3.output.';


# workgroup names

use constant DEFAULT_WORKGROUP => 'Barefoot';
use constant TEST_WORKGROUP => 'TestCompany';


# one sub; just don't want to clutter anybody's namespace with this

sub debug
{
	if (main::DEBUG)
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
				if main::DEBUG >= $level;
	}
}


###########################################################################

package Barefoot::T3::base;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<t3 t3_config t3_username t3_filenames timer_fields todo_fields>;

use Barefoot::base;
use Barefoot::config_file;


our $t3;									# DataStore for singleton

# need this for getting proper values out of config file (below)
our $workgroup = DEBUG ? T3::TEST_WORKGROUP
		: $ENV{T3_WORKGROUP} || T3::DEFAULT_WORKGROUP;

# let's read in the config file here and let people use t3_config
# to get various and sundry parameters out of it
# (saves having to read the config file in several times)
our $cfg_file = config_file->read(T3::CONFIG_FILE);

our %t3_file_ext =							# extensions for local files
(
	timer	=>	'.timer',
	todo	=>	'.todo',
);

our %t3_hist_file =							# local history files
(
	timer	=>	'timer.history',
	todo	=>	'todo.history',
);


###########################
# Subroutines:
###########################


sub t3
{
	$t3 = DataStore->open(DEBUG ? "t3test" : "T3", $ENV{USER})
			unless defined $t3;
	return $t3;
}


sub t3_config
{
	# just return lookup of current workgroup and first argument
    return $cfg_file->lookup($workgroup, $_[0]);
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

	# double check validity of which file
	# (this indicates a logic error)
	die("don't know extension for module $module")
			unless exists $t3_file_ext{$module};
	die("don't know history file for module $module")
			unless exists $t3_hist_file{$module};

    my $t3dir = t3_config(T3::TIMERDIR_DIRECTIVE);
	die("don't have a directory for timer files") unless $t3dir;
	die("cannot write to directory $t3dir") unless -d $t3dir and -w $t3dir;

    my $t3file = "$t3dir/$user" . $t3_file_ext{$module};
    my $histfile = "$t3dir/" . $t3_hist_file{$module};
	print "timer file is $t3file\n" if DEBUG >= 2;

	return ($t3file, $histfile);
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
