#! /usr/local/bin/perl

# For CVS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# cvs
#
###########################################################################
#
# This module contains support routines for CVS scripts.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 1999-2003 Barefoot Software.
#
###########################################################################

package cvs;

### Private ###############################################################

use strict;

use Carp;
use FileHandle;

use Barefoot::base;
use Barefoot::cvsdir;
use Barefoot::exception;

use constant CONTROL_DIR => "CONTROL";
use constant RELEASE_FILE => "RELEASE";


# for error messages
our $me = $0;
$me =~ s@^.*/@@;

# change below by calling cvs::set_cvsroot()
our $cvsroot = $ENV{CVSROOT};

# for internal use only (_get_lockers)
my %lockers_cache;


###########################
# Private Subroutines:
###########################


sub _interpret_editors_output
{
	# use 1st arg, or $_ if no args
	local $_ = $_[0] if @_;

	# cvs editors returns three types of lines:
	#	? module
	#		this line means that the module isn't in CVS
	#		in this case, return ("module", undef)
	#	module user  <a bunch of other stuff we don't care about>
	#		this line means that "module" is being edited by "user"
	#		in this case, return ("module", "user")
	#	<whitespace> user  <same bunch of other stuff we don't care about>
	#		this line means that the same module as the last line
	#			is also being edited by "user"
	#		in this case, return (undef, "user")
	#		note that for multiple lockers, the caller is responsible for
	#			remembering the module name

	if ( /^\?/ )
	{
		# illegal module; not checked into CVS
		my (undef, $module) = split();
		return ($module, undef);
	}
	elsif ( /^\s/ )
	{
		# same editor as previous module; just return username
		my ($user) = split();
		return (undef, $user);
	}
	else
	{
		# better be module and editor, else this will do funky things
		my ($module, $user) = split();
		return ($module, $user);
	}
}


sub _get_lockers
{
	my ($module) = @_;

	# check cache; if not found, get answer and cache it
	if (not exists $lockers_cache{$module})
	{
		my $lockers = [];

		my $ed = execute_and_get_output("editors", $module);
		while ( <$ed> )
		{
			my ($cvs_file, $user) = _interpret_editors_output();
			die("$me: unknown module $module (not in CVS)\n") unless $user;
			croak("illegal cvs editors output ($_)")
					if defined $cvs_file and $cvs_file ne $module;

			push @$lockers, $user;
		}
		close($ed);

		$lockers_cache{$module} = $lockers;
	}

	# return results (as array, not reference)
	return @{ $lockers_cache{$module} }
}


sub _make_cvs_command
{
	my $command = shift;
	my $opts = @_ && ref $_[$#_] eq "HASH" ? pop : {};

	my $quiet = $opts->{VERBOSE} ? "" : "-q";
	my $local = $opts->{RECURSE} ? "" : "-l";
	my $err_redirect = $opts->{IGNORE_ERRORS} ? "2>/dev/null" : "";

	return "cvs -r $quiet -d $cvsroot $command $local @_ $err_redirect ";
}


###########################
# Subroutines:
###########################


sub set_cvsroot
{
	$cvsroot = $_[0];
}


# call cvs and throw output away
sub execute_and_discard_output
{
	# just pass args through to _make_cvs_command
	my $cvs_cmd = &_make_cvs_command;

	my $err = system("$cvs_cmd >/dev/null 2>&1");
	die("$me: call to cvs command $_[0] failed with $! ($err)\n") if $err;
}


# call cvs and read output as if from a file
sub execute_and_get_output
{
	# just pass args through to _make_cvs_command
	my $cvs_cmd = &_make_cvs_command;

	my $fh = new FileHandle("$cvs_cmd |")
			or die("$me: call to cvs command $_[0] failed with $!\n");
	return $fh;
}


# check for general (i.e., non-file-specific) errors common to all programs
sub check_general_errors
{
	# must either set CVSROOT in environment, or pass in via -d (or equivalent)
	die("$me: CVS root directory must be set\n") unless $cvsroot;
}


sub exists
{
	my ($module) = @_;

	my $ed = execute_and_get_output("status", $module,
			{ IGNORE_ERRORS => true} );
	while ( <$ed> )
	{
		if ( /Status: (.*)$/ )
		{
			close($ed);
			return $1 ne "Unknown";
		}
	}
	close($ed);

	# this should really never happen
	die("can't get status from cvs status");
}


sub getLockers
{
	my ($new_cvsroot, $module, $user_locker_flag) = @_;

	# this function is depracated, so inform the user
	carp("getLockers is a depracated function; report to sys admin");

	# change cvsroot just for this function
	local $cvsroot = $new_cvsroot;

	# set flag ref if user is one of the lockers
	$$user_locker_flag = user_is_a_locker($module);

	# return lockers of the module
	return lockers($module);
}


sub user_is_a_locker
{
	# unix - USER, windows - USERNAME (some flavors anyway)
	# one of them needs to be set
	my $username = $ENV{USER} || $ENV{USERNAME};
	croak("user_is_a_locker: can't determine user name") unless $username;

	return grep { $_ eq $username } _get_lockers($_[0]);
}


sub lockers
{
	return _get_lockers($_[0]);
}


sub parse_module
{
	my ($path) = @_;

	my $wdir = WORKING_DIR;
	my ($project, $subdir, $module) = $path =~ m@
			# we don't use ^ here because there may be stuff before WORKING_DIR
			# e.g., a drive letter on Win systems, or leading dirs on Unix
			# systems if WORKING_DIR is implemented as a symlink
			$wdir				# should start with working directory
			/					# needs to be at least one dir below
			([^/]+)				# the next dirname is also the proj name
			(?:					# don't want to make a backref here, just group
				(?:				# ditto
					/(.*)		# any other directories underneath
				)?				# are optional
				/([^/]+)		# get the last component separately
			)?					# these last two things both are optional
		@x;

	if (!defined($project))		# pattern didn't match; probably doesn't
	{							# start with WORKING_DIR
		return ();				# return empty list to indicate error
	}

	if (-d $path)				# if the entire path is a directory
	{
		$subdir .= "/$module";	# then module is a dir; tack it on the subdir
		undef $module;			# and there is no module
	}

	return ($project, $subdir, $module);
}


sub project_group
{
	my ($project) = @_;

	my $project_gid = (stat("$::ENV{CVSROOT}/$project"))[5];
	my $project_grname = getgrgid($project_gid);
	return $project_grname;
}


sub is_offsite
{
	my ($cvsroot) = @_;

	# this function is depracated, so inform the user
	carp("getLockers is a depracated function; report to sys admin");

	if ( $cvsroot =~ /^\:pserver\:/ || $cvsroot =~ /^\:ext\:/ )
	{
		return 1;
	}
	else
	{
		return 0;
	}
}


###########################
# Return a true value:
###########################

1;
