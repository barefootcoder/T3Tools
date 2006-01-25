#! /usr/local/bin/perl -w

# For RCS:
# $Date: 2003/01/05 20:18:29 $
#
# $Id: db_get.pm,v 1.4 2003/01/05 20:18:29 buddy Exp $
# $Revision: 1.4 $

###########################################################################
#
# Barefoot::T3::db_get
#
###########################################################################
#
# This module contains routines which retreive various information from
# the T3 database.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package Barefoot::T3::db_get;

### Private ###############################################################

use strict;

use base qw<Exporter>;
use vars qw<@EXPORT_OK>;
@EXPORT_OK = qw <one_datum get_emp_id default_client client_rounding proj_requirements phase_list get_logs >;

use Barefoot::DataStore;

use Barefoot::T3::base;


###########################
# Subroutines:
###########################


sub one_datum
{
	my ($query, $err_msg) = @_;
	$err_msg ||= "query failed : $query";

	my $res = &t3->do($query);
	die($err_msg) unless $res and $res->next_row();

	return $res->col(0);
}


sub get_emp_id
{
	my ($user) = @_;

	my $res = &t3->do("
			select e.emp_id
			from {~t3}.workgroup_user wu, {~timer}.employee e
			where wu.nickname = '$user'
			and wu.person_id = e.person_id
	");
	die("default client query failed") unless $res and $res->next_row();
	return $res->col(0);
}


sub default_client
{
	my ($emp) = @_;

	my $res = &t3->do("
			select e.def_client
			from {~timer}.employee e
			where e.emp_id = '$emp'
	");
	die("default client query failed") unless $res and $res->next_row();
	return $res->col(0);
}


sub client_rounding
{
	my ($client) = @_;

	my $res = &t3->do("
			select c.rounding, c.to_nearest
			from {~timer}.client c
			where c.client_id = '$client'
	");
	die("client rounding query failed:", &t3->last_error())
			unless $res and $res->next_row();

	return $res->all_cols();
}


sub proj_requirements
{
	my ($client, $proj, $date) = @_;
	# print STDERR "client: $client, proj: $proj\n";

	my $res = &t3->do(q{
		select pt.requires_phase, pt.requires_tracking,
				pt.requires_comments
		from {~timer}.project p, {~timer}.project_type pt
		where p.client_id = {client}
		and p.proj_id = {proj}
		and {date} between p.start_date and p.end_date
		and p.project_type = pt.project_type
	},
		client => $client, proj => $proj, $date => $date,
	);
	die("project requirements query failed:", &t3->last_error()) unless $res;

	if ($res->next_row())
	{
		return $res->all_cols();
	}
	else
	{
		return (0,0,0);
	}
}


sub phase_list
{
	my $res = &t3->do(q{
		select ph.phase_id, ph.name
		from {~timer}.phase ph
	},
	);
	die("phase list query failed:", &t3->last_error()) unless $res;

	my $phases = {};
	while ($res->next_row())
	{
		$phases->{$res->col(0)} = $res->col(1);
	}
	return $phases;
}


sub get_logs
{
	my ($emp_id) = @_;

	my $data = &t3->load_data(q{
		select l.log_date, l.hours
		from {~timer}.time_log l
		where l.emp_id = {emp}
		order by l.log_date
	},
		emp => $emp_id,
	);
	die("get logs query failed:", &t3->last_error()) unless $data;

	return $data;
}


###########################
# Return a true value:
###########################

1;
