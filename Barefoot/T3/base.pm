#! /usr/local/bin/perl -w

# For RCS:
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

package Barefoot::T3::base;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT>;
@EXPORT = qw<t3 t3_username t3_filenames>;

use Barefoot::base;


# constants

use constant CONFIG_FILE => '/etc/t3.conf';

use constant DBSERVER_DIRECTIVE => 'DBServer';
use constant DATABASE_DIRECTIVE => 'Database';
use constant TIMERDIR_DIRECTIVE => 'TimerDir';

use constant DEFAULT_WORKGROUP => 'Barefoot';
#use constant DEFAULT_WORKGROUP => 'TestCompany';


our $t3;									# DataStore for singleton

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

    my $cfg_file = config_file->read(CONFIG_FILE);
    my $workgroup = $ENV{T3_WORKGROUP} || DEFAULT_WORKGROUP;

    my $t3dir = $cfg_file->lookup($workgroup, TIMERDIR_DIRECTIVE);
	die("don't have a directory for timer files") unless $t3dir;
	die("cannot write to directory $t3dir") unless -d $t3dir and -w $t3dir;

    my $t3file = "$t3dir/$user" . $t3_file_ext{$module};
    my $histfile = "$t3dir/" . $t3_hist_file{$module};
	print "timer file is $t3file\n" if DEBUG >= 2;

	return ($t3file, $histfile);
}


###########################
# Return a true value:
###########################

1;
