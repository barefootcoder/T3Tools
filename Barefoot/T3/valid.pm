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
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2007 Barefoot Software, Copyright (c) 2004-2007 ThinkGeek
#
###########################################################################

package Barefoot::T3::valid;

### Private ###############################################################

use strict;
use warnings;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw< get_parameter valid_employees valid_clients valid_projects valid_trackings >;

use Carp;
use Data::Dumper;

use Barefoot;
use Barefoot::input qw<input get_yn>;

use Barefoot::T3::base;
use Barefoot::T3::db_get qw< get_emp_id default_client phase_list queue_list >;


our %db_default =
(
	employee				=>	sub { $_[0]->{employee} = get_emp_id($_[0]->{'user'}) },
	client					=>	sub
								{
									$_[0]->{employee} = get_emp_id($_[0]->{'user'}) unless exists $_[0]->{employee};
									default_client($_[0]->{employee});
								},
	project					=>	sub
								{
									$_[0]->{employee} = get_emp_id($_[0]->{'user'}) unless exists $_[0]->{employee};
									"";
								},
	phase					=>	sub { "" },
	'client tracking code'	=>	sub { "" },
	queue					=>	sub { "" },
);

our %valid_function =
(
	employee				=>	sub { valid_employees() },
	client					=>	sub { valid_clients($_[0]->{employee}, $_[0]->{date}) },
	project					=>	sub { valid_projects($_[0]->{employee}, $_[0]->{client}, $_[0]->{date}) },
	phase					=>	sub { phase_list() },
	'client tracking code'	=>	sub { valid_trackings($_[0]->{client}) },
	queue					=>	sub { queue_list() },
);


###########################
# Subroutines:
###########################


sub get_parameter
{
	my ($parmname, $parminfo, $objinfo, $opts) = @_;
	debuggit(4 => "get_parameter: wantarray is", wantarray, "/ parminfo:", Dumper($parminfo));

	my $parm = "";														# set to empty in case we bail out early
	my $valid_parms = {};

	TRY:																# try several things to figure out just
	{																	# what the parameter's value should be

		# database default is lowest priority (based on dispatch table; if we don't have such a function,
		# better barf)
		croak("can't determine default value for $parmname") unless exists $db_default{$parmname};
		$parm = $db_default{$parmname}->($parminfo);
		debuggit(3 => "after db default, parm is", $parm);

		if (exists $objinfo->{$parmname})								# pre-existing parm - higher priority
		{
			$parm = $objinfo->{$parmname};
		}
		debuggit(3 => "after objinfo, parm is", $parm);

		if ($parminfo->{$parmname})										# program flags - highest priority
		{
			if ($opts->{RESTRICT_CHANGES} and exists $objinfo->{$parmname})
			{
				# not allowed to change the parameter via command-line:
				# use pre-existing if available
				print "Can't change pre-existing $parmname with this option: ",
						"value ignored. \n";
				last TRY;
			}
			elsif ($opts->{SAVE_IN_OBJECT} and exists $objinfo->{$parmname})
			{
				# if saving in object, allow object parameter to take priority
				# therefore, do nothing
			}
			else
			{
				$parm = $parminfo->{$parmname};
			}
		}
		debuggit(3 => "after parminfo, parm is", $parm);

		last TRY if $parminfo->{force};

		# get list of valid values (based on dispatch table; if we don't have such a function, better barf)
		# (note that this has to be done after figuring the database default, because that might set up some
		# values we need here)
		croak("can't determine valid list for $parmname") unless exists $valid_function{$parmname};
		$valid_parms = $valid_function{$parmname}->($parminfo);
		debuggit(4 => "valid_parms:", Dumper($valid_parms));
		
		# at this point, parm will act as our default
		# need to save it in case user enters "?", then we can put it back
		my $default = $parm;

		# make a block so redo will work
		PARM:
		{
			$parm = input("Which $parmname is this for? (? for list)", $default);
			$parm = uc($parm);											# codes are all UC
			$parm = string::trim($parm);								# no spaces

			if ($parm eq "?")
			{
				foreach my $id (keys %$valid_parms)
				{
					print "  {", $id, " - ", $valid_parms->{$id}, "}\n";
				}
				print "  / - remove value (i.e. enter NULL)\n" if $opts->{ALLOW_NULL};
				redo PARM;
			}

			if ($parm eq "/")
			{
				unless ($opts->{ALLOW_NULL})
				{
					print "you must supply a response\n";
					redo PARM;
				}
				$parm = undef;
			}

			# Checks value to be sure it's valid
			if (not defined $parm and $opts->{ALLOW_NULL})
			{
				print "\u$parmname will be blank (NULL).\n";
				last PARM;
			}
			foreach my $id (keys %$valid_parms)
			{
				if ($parm eq string::trim($id))
				{
					if ($parminfo->{noconfirm})
					{
						print "\u$parmname is $parm: $valid_parms->{$id}.\n";
					}
					else 												# ask for confirmation
					{
						redo PARM unless get_yn("\u$parmname is $parm: $valid_parms->{$id}; is this right?");
					}
					$parm = $id;
					last PARM;
				}
			}
			print "Invalid \u$parmname! \n";
			redo PARM;
		}
	}

	# save the value we got
	# default is to save in $parminfo, but can also save in $objinfo if $opts specifies this
	$parminfo->{$parmname} = $parm;
	if ($opts->{SAVE_IN_OBJECT})
	{
		$objinfo->{$parmname} = $parm;
	}

	debuggit(4 => Dumper($valid_parms));
	debuggit(3 => wantarray ?  "will return ($parm, $valid_parms->{$parm})" : "will return", $parm);

	# if force was specified, you'll get ($parm, undef)
	# if ALLOW_NULL was specified and the user chooses NULL, you'll get (undef, undef)
	return wantarray ? ($parm, $valid_parms->{$parm}) : $parm;
}


sub valid_employees
{
	my $res = &t3->do("
			select distinct e.emp_id, pe.first_name, pe.last_name
			from {~timer}.employee e, {~t3}.person pe, {~timer}.client_employee ce
			where e.person_id = pe.person_id
			and e.emp_id = {&ifnull ce.emp_id, e.emp_id}
			and {&today} between ce.start_date and ce.end_date
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
	my ($emp, $date) = @_;

	my $date_fld = $date ? '{date}' : '{&today}';
	my $res = &t3->do(qq{
			select distinct c.client_id, c.name
			from {~timer}.client c, {~timer}.employee e, {~timer}.client_employee ce
			where e.emp_id = {emp}
			and e.emp_id = {&ifnull ce.emp_id, e.emp_id}
			and c.client_id = ce.client_id
			and $date_fld between ce.start_date and ce.end_date
	},
		emp => $emp, date => date::mdy($date),
	);
	die("valid clients query failed:", &t3->last_error()) unless $res;

	my $clients = {};
	while ($res->next_row())
	{
		debuggit(5 => "valid cli:", $res->col(0), "=>", $res->col(1));
		$clients->{$res->col(0)} = $res->col(1);
	}
	return $clients;
}


sub valid_projects
{
	my ($emp, $client, $date) = @_;

	my $date_fld = $date ? '{date}' : '{&today}';
	my $res = &t3->do(qq{
			select distinct p.proj_id, p.name
			from {~timer}.project p, {~timer}.employee e, {~timer}.client_employee ce
			where p.client_id = {client}
			and $date_fld between p.start_date and p.end_date
			and e.emp_id = {emp}
			and e.emp_id = {&ifnull ce.emp_id, e.emp_id}
			and p.client_id = ce.client_id
			and
			(
				p.proj_id = ce.proj_id
				or ce.proj_id is NULL
			)
			and $date_fld between ce.start_date and ce.end_date
	},
		emp => $emp, client => $client, date => date::mdy($date),
	);
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
