#! /usr/local/bin/perl

# For RCS:
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
# licensing agreement.  Copyright (c) 1999 Barefoot Software.
#
###########################################################################

package cvs;

### Private ###############################################################

use strict;

use constant WORKING_DIR => "/proj/" .
		scalar(exists $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : $ENV{USER});


1;


#
# Subroutines:
#


sub getLockers
{
	my ($cvsroot, $module, $flag_ref) = @_;

	# unix - USER, windows - USERNAME (some flavors anyway)
	# one of them needs to be set
	my $username = $::ENV{USER};
	$username = $::ENV{USERNAME} if !$username;

	my @lockers = ();

	open(ED, "cvs -d $cvsroot editors $module |") or 
									die("getLockers: can't open pipe");
	while ( <ED> )
	{
		my @fields = split();
		my $user = $fields[0] eq $module ? $fields[1] : $fields[0];
		$$flag_ref = 1 if defined $flag_ref and $user eq $username;
		push @lockers, $user;
	}
	close(ED);

	return @lockers;
}


sub parse_module
{
	my ($path) = @_;

	my $wdir = WORKING_DIR;
	my ($project, $subdir, $module) = $path =~ m@
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

	if ( $cvsroot =~ /^\:pserver\:/ || $cvsroot =~ /^\:ext\:/ )
	{
		return 1;
	}
	else
	{
		return 0;
	}
}
