#! /usr/local/bin/perl

# For RCS:
# $Date$
# $Log$
# Revision 1.1  1999/11/22 15:02:38  buddy
# Initial revision
#
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

# in the following, ~ indicates the user's name
use constant WORKING_DIR => "/export/usr/~/proj";

1;


#
# Subroutines:
#


sub working_dir
{
	my $wdir = WORKING_DIR;
	$wdir =~ s/~/$ENV{USER}/;
	return $wdir;
}

sub getLockers
{
	my ($module, $flag_ref) = @_;

	# we assume that module is valid; all checking should be done
	# before this function is called

	my @lockers = ();

	open(ED, "cvs editors $module |") or die("getLockers: can't open pipe");
	while ( <ED> )
	{
		my @fields = split();
		my $user = $fields[0] eq $module ? $fields[1] : $fields[0];
		$$flag_ref = 1 if defined $flag_ref and $user eq $::ENV{USER};
		push @lockers, $user;
	}
	close(ED);

	return @lockers;
}

sub parse_module
{
	my ($path) = @_;

	my $wdir = working_dir();
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
