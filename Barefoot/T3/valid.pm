#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::valid
#
###########################################################################
#
# This module holds a few validation routines for T3 modules.  These are
# mainly used by the command-line clients.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package Barefoot::T3::valid;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw<get_parameter valid_employees valid_clients valid_projects
		valid_trackings>;

use Carp;

use Barefoot::base;
use Barefoot::input qw<input get_yn>;

use Barefoot::T3::base;
use Barefoot::T3::db_get qw<get_emp_id default_client phase_list>;


our %db_default =
(
	employee	=>	sub { $_[0]->{employee} = get_emp_id($_[0]->{user}) },
	client		=>	sub {
							$_[0]->{employee} = get_emp_id($_[0]->{user})
									unless exists $_[0]->{employee};
							default_client($_[0]->{employee});
					},
	project		=>	sub {
							$_[0]->{employee} = get_emp_id($_[0]->{user})
									unless exists $_[0]->{employee};
							"";
					},
	phase		=>	sub { ""; },
	'client tracking code'
				=>	sub { ""; },
);

our %valid_function =
(
	employee	=>	sub { valid_employees() },
	client		=>	sub { valid_clients($_[0]->{employee}) },
	project		=>	sub { valid_projects($_[0]->{employee}, $_[0]->{client}) },
	phase		=>	sub { phase_list() },
	'client tracking code'
				=> sub { valid_trackings($_[0]->{client}) },
);


###########################
# Subroutines:
###########################


sub get_parameter
{
	my ($parmname, $parminfo, $objinfo, $opts) = @_;

	# database default is lowest priority
	# (based on dispatch table; if we don't have such a function, better barf)
	croak("can't determine default value for $parmname")
			unless exists $db_default{$parmname};
	my $parm = $db_default{$parmname}->($parminfo);
	print "after db default, parm is $parm\n" if DEBUG >= 3;

	if (exists $objinfo->{$parmname})# pre-existing parm - higher priority
	{
		$parm = $objinfo->{$parmname};
	}
	print "after objinfo, parm is $parm\n" if DEBUG >= 3;

	if ($parminfo->{$parmname})		# program flags - highest priority
	{
		if ($opts->{RESTRICT_CHANGES} and exists $objinfo->{$parmname})
		{
			# not allowed to change the parameter via command-line:
			# use pre-existing if available
			print "Can't change pre-existing $parmname with this option: ",
					"value ignored. \n";
			return $parm;
		}
		else
		{
			$parm = $parminfo->{$parmname};
		}
	}
	print "after parminfo, parm is $parm\n" if DEBUG >= 3;

	return $parm if $parminfo->{force};

	# get list of valid values (based on dispatch table;
	# if we don't have such a function, better barf)
	# (note that this has to be done after figuring the database default,
	# because that might set up some values we need here)
	croak("can't determine valid list for $parmname")
			unless exists $valid_function{$parmname};
	my $valid_parms = $valid_function{$parmname}->($parminfo);
	
	# at this point, parm will act as our default
	# need to save it in case user enters "?", then we can put it back
	my $default = $parm;

	# make a block so redo will work
	PARM:
	{
		$parm = input("Which $parmname is this for? (? for list)", $default);
		$parm = string::upper($parm);				# codes are all UC
		$parm = string::trim($parm);				# no spaces

		if ($parm eq "?")
		{
			foreach my $id (keys %$valid_parms)
			{
				print "  {", $id, " - ", $valid_parms->{$id}, "}\n";
			}
			redo PARM;
		}

		# Checks value to be sure it's valid
		foreach my $id (keys %$valid_parms)
		{
			if ($parm eq string::trim($id))
			{
				if ($parminfo->{noconfirm})
				{
					print "\u$parmname is $parm: $valid_parms->{$id}.\n";
				}
				else 		# ask for confirmation
				{
					redo PARM unless get_yn("\u$parmname is $parm: "
							. "$valid_parms->{$id}; is this right?");
				}
				$parm = $id;
				last PARM;
			}
		}
		print "Invalid \u$parmname! \n";
		redo PARM;
	}

	# save the value we got
	$parminfo->{$parmname} = $parm;

	return wantarray ? ($parm, $valid_parms->{$parm}) : $valid_parms->{$parm};
}


sub valid_employees
{
	my $res = &t3->do("
			select e.emp_id, pe.first_name, pe.last_name
			from {~timer}.employee e, {~t3}.person pe
			where e.person_id = pe.person_id
			and exists
			(
				select 1
				from {~timer}.client_employee ce
				where e.emp_id = ce.emp_id
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid employees query failed:", &t3->last_error()) unless $res;

	my $emps = {};
	while ($res->next_row())
	{
		$emps->{$res->col(0)} = $res->col(1) . " " . $res->col(2);
	}
	return $emps;
}


sub valid_clients
{
	my ($emp) = @_;

	my $res = &t3->do("
			select c.client_id, c.name
			from {~timer}.client c
			where exists
			(
				select 1
				from {~timer}.employee e, {~timer}.client_employee ce
				where e.emp_id = '$emp'
				and e.emp_id = ce.emp_id
				and c.client_id = ce.client_id
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid clients query failed:", &t3->last_error()) unless $res;

	my $clients = {};
	while ($res->next_row())
	{
		# print STDERR "valid cli: ", $res->col(0), " => ", $res->col(1), "\n";
		$clients->{$res->col(0)} = $res->col(1);
	}
	return $clients;
}


sub valid_projects
{
	my ($emp, $client) = @_;

	my $res = &t3->do("
			select p.proj_id, p.name
			from {~timer}.project p
			where p.client_id = '$client'
			and {&curdate} between p.start_date and p.end_date
			and exists
			(
				select 1
				from {~timer}.employee e, {~timer}.client_employee ce
				where e.emp_id = '$emp'
				and e.emp_id = ce.emp_id
				and p.client_id = ce.client_id
				and
				(
					p.proj_id = ce.proj_id
					or ce.proj_id is NULL
				)
				and {&curdate} between ce.start_date and ce.end_date
			)
	");
	die("valid projects query failed:", &t3->last_error()) unless $res;

	my $projects = {};
	while ($res->next_row())
	{
		# print STDERR "valid proj: ", $res->col(0), " => ", $res->col(1), "\n";
		$projects->{$res->col(0)} = $res->col(1);
	}
	return $projects;
}


sub valid_trackings
{
	my ($client) = @_;

	my $res = &t3->do("
			select ct.tracking_code, ct.name
			from {~timer}.client_tracking ct
			where ct.client_id = '$client'
	");
	die("valid trackings query failed:", &t3->last_error()) unless $res;

	my $track = {};
	while ($res->next_row())
	{
		$track->{$res->col(0)} = $res->col(1);
	}
	return $track;
}


###########################
# Return a true value:
###########################

1;
