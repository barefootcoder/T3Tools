#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::T3::TimerProcs
#
###########################################################################
#
# These are the equivalent of stored procedures for Timer.  They are more
# powerful than stored procedures because they allow you to build SQL on
# the fly.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package T3::TimerProcs;

### Private ###############################################################

use strict;

use Barefoot::debug(1);

use Carp;

use Barefoot::DataStore;
use Barefoot::DataStore::procs;


# have to "register" all procs with DataStore
$DataStore::procs->{build_pay_amount} = \&build_pay_amount;
$DataStore::procs->{build_profit_item} = \&build_profit_item;


1;


#
# Subroutines:
#


# helper routines


sub _fatal
{
	croak("procedure error: ", $_[0]->last_error());
}

sub _do_or_error
{
	my ($ds, $query, @values) = @_;

	croak("not ready to handle placeholders") if @values;

	my $res = $ds->do($query);
	_fatal($ds) unless $res;
}


# main procedures


###########################################################################
#
# build_pay_amount
#
# #########################################################################
#
# Use this procedure when you only want to calculate amounts to pay to
# employees and subcontractors.  If you also need to calculate billing
# amounts, and/or profits, just call build_profit_item; that procedure
# will automatically call this one.
#
# This procedure fills the pay_amount reporting table with records that
# match the where clause you specify (remember, do not actually include
# the word "where" in your clause, and do not begin it with "and"; those
# things will be done by the procedure).  It then calculates the proper
# pay rates for each log specified using the pay_rate table.
#
# The following aliases are available to your where clause:
#
#		log			log table
#		p			project
#		pt			projec_type
#
# If you need any other tables, you will have to specify an "exists"
# subquery.  In build_pay_amount (unlike build_profit_item), the log
# table is always time_log.  However, it is not necessarily a good idea
# to assume that.  It is, however, okay to assume that whatever the log
# table is, it has an emp_id column (the join to pay_rate demands that).
#
###########################################################################


sub build_pay_amount
{
	my ($ds, $where_clause) = @_;
	$where_clause = "and $where_clause" if $where_clause;

			print STDERR "about to do delete\n" if DEBUG >= 5;
		# clear out the old data
	_do_or_error($ds, "

		delete from {%reporting}.pay_amount
	");

			print STDERR "about to do insert\n" if DEBUG >= 5;
		# put in the new data
	_do_or_error($ds, "

		insert into {%reporting}.pay_amount
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
				pay_date, hours, requires_payment, requires_billing)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				pt.requires_payment, pt.requires_billing
		from {%timer}.time_log log, {%timer}.project p,
				{%timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and log.log_date between p.start_date and p.end_date
		and p.project_type = pt.project_type
		$where_clause
	");

			print STDERR "about to get gen rates\n" if DEBUG >= 5;
		# get general employee rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pr.client_id is NULL
			and pr.proj_id is NULL
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to get phase rates\n" if DEBUG >= 5;
		# get general employee/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pr.client_id is NULL
			and pr.proj_id is NULL
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to get client rates\n" if DEBUG >= 5;
		# get general employee/client rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pr.proj_id is NULL
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to get client/phase rates\n" if DEBUG >= 5;
		# get general employee/client/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pr.proj_id is NULL
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to get client/proj rates\n" if DEBUG >= 5;
		# get specific employee/client/project rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pa.proj_id = pr.proj_id
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to get client/proj/phase rates\n" if DEBUG >= 5;
		# get specific employee/client/project/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.pay_amount", "pa",
		# set
			[ "pay_rate = pr.rate", "pay_rate_type = pr.rate_type" ],
		"
			from {%timer}.pay_rate pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pa.proj_id = pr.proj_id
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	");

			print STDERR "about to set zero rates\n" if DEBUG >= 5;
		# if it doesn't require payment, change rate to 0
	_do_or_error($ds, "

		update {%reporting}.pay_amount
		set pay_rate = 0
		where requires_payment = 0
	");

			print STDERR "about to set total pay\n" if DEBUG >= 5;
		# now figure the actual total pay
	my $data = $ds->load_table("select * from {%reporting}.pay_amount")
			or _fatal($ds);
	foreach (@$data)
	{
		$_->{total_pay} = range::round($_->{pay_rate} * $_->{hours},
				range::ROUND_UP, .01);
		print STDERR "  total_pay: $_->{total_pay}\n" if DEBUG >= 5;
	}
			print STDERR "calling replace_table\n" if DEBUG >= 5;
	$ds->replace_table("{%reporting}.pay_amount", $data) or _fatal($ds);

			print STDERR "returning\n" if DEBUG >= 5;
	# we don't really want any output from this
	return "";
}


###########################################################################
#
# build_profit_item
#
# #########################################################################
#
# Use this procedure when you want to calculate amounts to bill clients.
# This procedure will call build_pay_amount for you.  If you also need to
# calculate profits and/or commissions, you will have to call this procedure
# *and* any other relevant procedures.
#
# This procedure fills the time_log_profit and profit_item reporting tables
# with records that match the where clause you specify (remember, do not
# actually include the word "where" in your clause, and do not begin it with
# "and"; those things will be done by the procedure).  It then calculates
# the proper billing rates for each log specified using the pay_rate table.
#
# The following aliases are available to your where clause:
#
#		log			log table
#		p			project
#		pt			projec_type
#
# If you need any other tables, you will have to specify an "exists"
# subquery.  The log table may be time_log, materials_log, or class_log
# (or any other log table there might be in the future).  Your where
# clause will be applied to all of them.  Because of this, you may *not*
# refer to emp_id (or any other column which is not common to all three
# tables).
#
###########################################################################


sub build_profit_item
{
	my ($ds, $where_clause) = @_;

		print STDERR "about to call build_pay_amount\n" if DEBUG >= 5;
	# first get our pay amounts all straight
	build_pay_amount($ds, $where_clause);
		print STDERR "returned from build_pay_amount\n" if DEBUG >= 5;

	# provide leading "and"
	# (can't do this before calling build_pay_amount, or we'll end up
	# with "and and" in that procedure)
	$where_clause = "and $where_clause" if $where_clause;

	# in order to handle projects which demand profit calculated at
	# the end of the project, we'll have to substitute the project end
	# date for any requests on the log date
	# (if no requests on the log date were made, that's okay too)
	my $end_profit_where_clause = $where_clause;
	$end_profit_where_clause =~ s/ \b log\.log_date \b /p.end_date/xg;

			print STDERR "about to do deletes\n" if DEBUG >= 5;
		# clear out the old data
	_do_or_error($ds, "

		delete from {%reporting}.time_log_profit
	");
	_do_or_error($ds, "

		delete from {%reporting}.profit_item
	");

		# for time logs, we'll need to use the time_log_profit table
		# we will insert them into profit_item later (down below)
		# note that we insert a default billing ratio of 1
		# (this may get overriden when we start looking at billing ratios)

		# first, get time logs that will be one profit item each
	_do_or_error($ds, "

		insert {%reporting}.time_log_profit
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
					log_date, hours, start_date, end_date,
					requires_payment, resource_billing, class_billing,
					billing_ratio, sum_by_proj)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				log.log_date, log.log_date, pt.requires_payment,
				pt.resource_billing, pt.class_billing, 1, 0
		from {%timer}.time_log log, {%timer}.project p,
				{%timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and log.log_date between p.start_date and p.end_date
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 0
		$where_clause
	");

		# next, get time logs that will be summed
		# into one profit item per project
	_do_or_error($ds, "

		insert {%reporting}.time_log_profit
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
					log_date, hours, start_date, end_date,
					requires_payment, resource_billing, class_billing,
					billing_ratio, sum_by_proj)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				p.start_date, p.end_date, pt.requires_payment,
				pt.resource_billing, pt.class_billing, 1, 1
		from {%timer}.time_log log, {%timer}.project p,
				{%timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and log.log_date between p.start_date and p.end_date
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 1
		$end_profit_where_clause
	");

		# now get any billing ratios that might apply

		# STEP 1: general client billing ratios
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {%timer}.billing_ratio brat
			where tlp.emp_id = brat.emp_id
			and tlp.client_id = brat.client_id
			and brat.proj_id is NULL
			and brat.phase_id is NULL
			and tlp.log_date between brat.start_date and brat.end_date
	");

		# STEP 2: project specific billing ratios
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {%timer}.billing_ratio brat
			where tlp.emp_id = brat.emp_id
			and tlp.client_id = brat.client_id
			and tlp.proj_id = brat.proj_id
			and brat.phase_id is NULL
			and tlp.log_date between brat.start_date and brat.end_date
	");

		# STEP 3: phase specific billing ratios
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {%timer}.billing_ratio brat
			where tlp.emp_id = brat.emp_id
			and tlp.client_id = brat.client_id
			and tlp.proj_id = brat.proj_id
			and tlp.phase_id = brat.phase_id
			and tlp.log_date between brat.start_date and brat.end_date
	");

		# now figure billing rate

		# STEP 1: project billing rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = br.rate",
					"fixed_price_days = br.fixed_price_days" ],
		"
			from {%timer}.bill_rate br
			where tlp.resource_billing = 0
			and tlp.class_billing = 0
			and tlp.client_id = br.client_id
			and tlp.proj_id = br.proj_id
			and tlp.log_date between br.start_date and br.end_date
	");

		# STEP 2: resource billing rates (all phases)
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = rr.rate" ],
		"
			from {%timer}.resource_employee re, {%timer}.resource_rate rr
			where tlp.resource_billing = 1
			and tlp.class_billing = 0
			and tlp.emp_id = re.emp_id
			and re.phase_id is NULL
			and tlp.client_id = re.client_id
			and tlp.log_date between re.start_date and re.end_date
			and re.client_id = rr.client_id
			and re.resource_id = rr.resource_id
			and tlp.log_date between rr.start_date and rr.end_date
	");

		# STEP 3: resource billing rates (phase specific)
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{%reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = rr.rate" ],
		"
			from {%timer}.resource_employee re, {%timer}.resource_rate rr
			where tlp.resource_billing = 1
			and tlp.class_billing = 0
			and tlp.emp_id = re.emp_id
			and tlp.phase_id = re.phase_id
			and tlp.client_id = re.client_id
			and tlp.log_date between re.start_date and re.end_date
			and re.client_id = rr.client_id
			and re.resource_id = rr.resource_id
			and tlp.log_date between rr.start_date and rr.end_date
	");

		# insert individual time logs
	my $data = $ds->load_table("

		select tlp.client_id, tlp.proj_id, tlp.start_date, tlp.end_date,
				tlp.log_source, tlp.log_id,
					tlp.hours, tlp.billing_ratio, c.to_nearest,
				bill_rate as price_per_unit
		from {%reporting}.time_log_profit tlp, {%timer}.client c
		where tlp.class_billing = 0
		and tlp.sum_by_proj = 0
		and tlp.fixed_price_days is NULL
		and tlp.client_id = c.client_id
		and tlp.bill_rate is not NULL
	") or _fatal($ds);
	foreach (@$data)
	{
		my ($hours, $ratio, $to_nearest)
				= delete @$_{ qw<hours billing_ratio to_nearest> };
		$_->{units} = range::round($hours / $ratio,
				range::ROUND_UP, $to_nearest);
	}
	$ds->append_table("{%reporting}.profit_item", $data) or _fatal($ds);

=comment
		# sum "full project" time logs
		insert profit_item
			(client, proj, start_date, end_date, log_source, units,
					price_per_unit)
		select tlp.client, tlp.proj, tlp.start_date, tlp.end_date,
				'time_log SUM', 1,
				sum($(round "tlp.hours / tlp.billing_ratio" c.to_nearest U)
						* tlp.bill_rate)
		from time_log_profit tlp, client c
		where tlp.class_billing = 0
		and tlp.sum_by_proj = 1
		and tlp.fixed_price_days is NULL
		and tlp.client = c.client
		and tlp.bill_rate is not NULL
		group by tlp.client, tlp.proj, tlp.start_date, tlp.end_date

		# in order to figure out fixed price days stuff, we
		# have to figure out which periods apply
		# note that for this particular one, it won't matter whether
		# it's "full project" billing or not
		# PLEASE NOTE! if the dates passed to this procedure don't line
		# up with the boundaries of fixed price days billing periods,
		# you're likely to get pretty strange results
		insert profit_item
			(client, proj, start_date, end_date, log_source, units,
					price_per_unit)
		select distinct tlp.client, tlp.proj,
				$(period_start "$(period_num tlp.log_date					\
						tlp.fixed_price_days)" tlp.fixed_price_days),
				$(period_end "$(period_num tlp.log_date						\
						tlp.fixed_price_days)" tlp.fixed_price_days),
				'time_log FIXED', 1, tlp.bill_rate
		from {%reporting}.time_log_profit tlp
		where tlp.fixed_price_days is not NULL
		and tlp.bill_rate is not NULL
=cut

		# the remainder we can insert directly into profit_item
		# (which is cake compared to the above ...)

		# now insert relevant materials logs
		# (they're pretty easy, even though there's three "types" of them)
		# STEP 1: materials logs with no project
	_do_or_error($ds, "

		insert {%reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select client_id, proj_id, log_date, log_date, log_source, log_id,
				1, amount_billed
		from {%timer}.materials_log log
		where proj_id is null
		$where_clause
	");

		# STEP 2: materials logs for projects with "now" profit calculation
	_do_or_error($ds, "

		insert {%reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log.log_source, log.log_id, 1, log.amount_billed
		from {%timer}.materials_log log, {%timer}.project p,
				{%timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 0
		$where_clause
	");

		# STEP 3: materials logs for projects with "at end" profit calculation
	_do_or_error($ds, "

		insert {%reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log.log_source, log.log_id, 1, log.amount_billed
		from {%timer}.materials_log log, {%timer}.project p,
				{%timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 1
		$end_profit_where_clause
	");

=comment
		# get class logs that are one item per class
	_do_or_error($ds, "

		insert {%reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id, units,
					price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log_source, log_id,
				datediff(minute, log.start_time, log.end_time) / 60.0
						- (isnull(log.num_breaks, 0) * .25),
				log.num_students * br.rate
		from {%timer}.class_log log, {%timer}.project p,
				{%timer}.project_type pt, {%timer}.bill_rate br
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and log.log_date between p.start_date and p.end_date
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 0
		and log.client_id = br.client_id
		and log.proj_id = br.proj_id
		and log.log_date between br.start_date and br.end_date
		$where_clause
	");

		# get class logs that are "full project" quantities
		insert profit_item
			(client, proj, start_date, end_date, log_source, units,
					price_per_unit)
		select log.client, log.proj, p.start_date, p.end_date, 'class_log SUM',
				1, sum((datediff(minute, log.start_time, log.end_time) / 60.0
						- (isnull(log.num_breaks, 0) * .25))
						* log.num_students * br.rate)
		from class_log log, project p, project_type pt, bill_rate br
		where $end_profit_where_clause
		and log.client = p.client
		and log.proj = p.proj
		and p.proj_type = pt.proj_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 1
		and log.client = br.client
		and log.proj = br.proj
		and log.log_date between br.start_date and br.end_date
		group by log.client, log.proj, p.start_date, p.end_date
	");

		# now a slightly tricky part ... we'll need to get any time logs
		# that apply to the class logs, so that profit can be calculated
		# appropriately ... of course, there's always the possibility that
		# they're already there, so we have to be careful
		insert {%reporting}.time_log_profit
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
					log_date, hours, start_date, end_date, requires_payment,
					resource_billing, class_billing, billing_ratio, sum_by_proj)
		select log.log_source, log.log_id, log.emp, log.client, log.proj,
				log.phase, log.log_date, log.hours, log.log_date, log.log_date,
				pt.requires_payment, pt.resource_billing,
				pt.class_billing, 1, 0
		from profit_item pi, time_log log, project p, project_type pt
		where pi.log_source like 'class_log%'
		and pi.client = log.client
		and pi.proj = log.proj
		and log.log_date between pi.start_date and pi.end_date
		and log.client = p.client
		and log.proj = p.proj
		and p.proj_type = pt.proj_type
		and not exists
		(
			select 1
			from {%reporting}.time_log_profit tlp
			where log.log_source = tlp.log_source
			and log.log_id = tlp.log_id
		)
=cut

		# whew! now that we have all the profit items set, we can calculate
		# the total price (which is after all the point of all this)
	_do_or_error($ds, "

		update {%reporting}.profit_item
		set total_price = units * price_per_unit
	");

	# we don't really want any output from this
	return "";
}