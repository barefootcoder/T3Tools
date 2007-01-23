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
use warnings;

use Carp;
use Time::Local;
use Date::Parse;
use Data::Dumper;

use Barefoot::base;
use Barefoot::range;
use Barefoot::exception;
use Barefoot::DataStore;
use Barefoot::DataStore::Procs;
use Barefoot::DataStore::DataSet;

use constant BAREFOOT_EPOCH => '1/31/1994';
use Barefoot::date epoch => BAREFOOT_EPOCH;


# have to "register" all procs with DataStore
$DataStore::procs->{build_pay_amount} = \&build_pay_amount;
$DataStore::procs->{build_profit_item} = \&build_profit_item;
$DataStore::procs->{calc_profit} = \&calc_profit;
$DataStore::procs->{calc_sales_commission} = \&calc_sales_commission;
$DataStore::procs->{calc_ref_commission} = \&calc_referral_commission;
$DataStore::procs->{calc_emp_commission} = \&calc_employee_commission;
$DataStore::procs->{calc_admin_commission} = \&calc_admin_commission;
$DataStore::procs->{calc_insurance_contribution}
		= \&calc_insurance_contribution;
$DataStore::procs->{calc_salary_bank} = \&calc_salary_bank;


1;


#
# Subroutines:
#



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
###########################################################################
# helper routines
# for internal use only
###########################################################################
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


sub _fatal
{
	croak("procedure error: ", $_[0]->last_error());
}

sub _do_or_error
{
	my $ds = $_[0];
	my $res = &DataStore::do;
	_fatal($ds) unless $res;
}



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
###########################################################################
# main procedures
# for use by SQL reports
###########################################################################
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


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
#		pt			project_type
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
	_do_or_error($ds, '

		delete from {@pay_amount}
	');

			print STDERR "about to do insert\n" if DEBUG >= 5;
		# put in the new data
	_do_or_error($ds, '

		insert into {@pay_amount}
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
				pay_date, hours, requires_payment, requires_billing)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				pt.requires_payment, pt.requires_billing
		from {@time_log} log, {@project} p, {@project_type} pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and log.log_date between p.start_date and p.end_date
		and p.project_type = pt.project_type '
		. $where_clause
	);

			print STDERR "about to get gen rates\n" if DEBUG >= 5;
		# get general employee rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pr.client_id is NULL
			and pr.proj_id is NULL
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to get phase rates\n" if DEBUG >= 5;
		# get general employee/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pr.client_id is NULL
			and pr.proj_id is NULL
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to get client rates\n" if DEBUG >= 5;
		# get general employee/client rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pr.proj_id is NULL
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to get client/phase rates\n" if DEBUG >= 5;
		# get general employee/client/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pr.proj_id is NULL
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to get client/proj rates\n" if DEBUG >= 5;
		# get specific employee/client/project rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pa.proj_id = pr.proj_id
			and pr.phase_id is NULL
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to get client/proj/phase rates\n" if DEBUG >= 5;
		# get specific employee/client/project/phase rates
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@pay_amount}', 'pa',
		# set
			[ 'pay_rate = pr.rate', 'pay_rate_type = pr.rate_type' ],
		'
			from {@pay_rate} pr
			where pa.emp_id = pr.emp_id
			and pa.client_id = pr.client_id
			and pa.proj_id = pr.proj_id
			and pa.phase_id = pr.phase_id
			and pa.pay_date between pr.start_date and pr.end_date
	');

			print STDERR "about to set zero rates\n" if DEBUG >= 5;
		# if it doesn't require payment, change rate to 0
	_do_or_error($ds, '

		update {@pay_amount}
		set pay_rate = 0
		where requires_payment = 0
	');

			print STDERR "about to set total pay\n" if DEBUG >= 5;
		# now figure the actual total pay
	my $data = $ds->load_table('select * from {@pay_amount}')
			or _fatal($ds);
	$data->foreach_row(sub
	{
		$_->{total_pay} = range::round($_->{pay_rate} * $_->{hours},
				range::ROUND_UP, .01);
		print STDERR "  total_pay: $_->{total_pay}\n" if DEBUG >= 5;
	});
			print STDERR "calling replace_table\n" if DEBUG >= 5;
	$ds->replace_table("{~reporting}.pay_amount", $data) or _fatal($ds);

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

		delete from {~reporting}.time_log_profit
	");
	_do_or_error($ds, "

		delete from {~reporting}.profit_item
	");

		# for time logs, we'll need to use the time_log_profit table
		# we will insert them into profit_item later (down below)
		# note that we insert a default billing ratio of 1
		# (this may get overriden when we start looking at billing ratios)

		# first, get time logs that will be one profit item each
	_do_or_error($ds, "

		insert {~reporting}.time_log_profit
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
					log_date, hours, start_date, end_date,
					requires_payment, resource_billing, class_billing,
					billing_ratio, sum_by_proj)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				log.log_date, log.log_date, pt.requires_payment,
				pt.resource_billing, pt.class_billing, 1, 0
		from {~timer}.time_log log, {~timer}.project p,
				{~timer}.project_type pt
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

		insert {~reporting}.time_log_profit
			(log_source, log_id, emp_id, client_id, proj_id, phase_id,
					log_date, hours, start_date, end_date,
					requires_payment, resource_billing, class_billing,
					billing_ratio, sum_by_proj)
		select log.log_source, log.log_id, log.emp_id, log.client_id,
				log.proj_id, log.phase_id, log.log_date, log.hours,
				p.start_date, p.end_date, pt.requires_payment,
				pt.resource_billing, pt.class_billing, 1, 1
		from {~timer}.time_log log, {~timer}.project p,
				{~timer}.project_type pt
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
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {~timer}.billing_ratio brat
			where tlp.emp_id = brat.emp_id
			and tlp.client_id = brat.client_id
			and brat.proj_id is NULL
			and brat.phase_id is NULL
			and tlp.log_date between brat.start_date and brat.end_date
	");

		# STEP 2: project specific billing ratios
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {~timer}.billing_ratio brat
			where tlp.emp_id = brat.emp_id
			and tlp.client_id = brat.client_id
			and tlp.proj_id = brat.proj_id
			and brat.phase_id is NULL
			and tlp.log_date between brat.start_date and brat.end_date
	");

		# STEP 3: phase specific billing ratios
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "billing_ratio = brat.ratio" ],
		"
			from {~timer}.billing_ratio brat
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
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = br.rate",
					"fixed_price_days = br.fixed_price_days" ],
		"
			from {~timer}.bill_rate br
			where tlp.resource_billing = 0
			and tlp.class_billing = 0
			and tlp.client_id = br.client_id
			and tlp.proj_id = br.proj_id
			and tlp.log_date between br.start_date and br.end_date
	");

		# STEP 2: resource billing rates (all phases)
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = rr.rate" ],
		"
			from {~timer}.resource_employee re, {~timer}.resource_rate rr
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
			"{~reporting}.time_log_profit", "tlp",
		# set
			[ "bill_rate = rr.rate" ],
		"
			from {~timer}.resource_employee re, {~timer}.resource_rate rr
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
				tlp.log_source, tlp.log_id, tlp.hours, tlp.billing_ratio,
				c.to_nearest, bill_rate as price_per_unit
		from {~reporting}.time_log_profit tlp, {~timer}.client c
		where tlp.class_billing = 0
		and tlp.sum_by_proj = 0
		and tlp.fixed_price_days is NULL
		and tlp.client_id = c.client_id
		and tlp.bill_rate is not NULL
	") or _fatal($ds);
	$data->add_column("units", sub
	{
		my ($hours, $ratio, $to_nearest)
				= @$_{ qw<hours billing_ratio to_nearest> };
		return range::round($hours / $ratio, range::ROUND_UP, $to_nearest);
	});
	$data->remove_column($_) foreach qw<hours billing_ratio to_nearest>;
	$ds->append_table("{~reporting}.profit_item", $data) or _fatal($ds);

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
		from {~reporting}.time_log_profit tlp
		where tlp.fixed_price_days is not NULL
		and tlp.bill_rate is not NULL
=cut

		# the remainder we can insert directly into profit_item
		# (which is cake compared to the above ...)

		# now insert relevant materials logs
		# (they're pretty easy, even though there's three "types" of them)
		# STEP 1: materials logs with no project
	_do_or_error($ds, "

		insert {~reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select client_id, proj_id, log_date, log_date, log_source, log_id,
				1, amount_billed
		from {~timer}.materials_log log
		where proj_id is null
		$where_clause
	");

		# STEP 2: materials logs for projects with "now" profit calculation
	_do_or_error($ds, "

		insert {~reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log.log_source, log.log_id, 1, log.amount_billed
		from {~timer}.materials_log log, {~timer}.project p,
				{~timer}.project_type pt
		where log.client_id = p.client_id
		and log.proj_id = p.proj_id
		and p.project_type = pt.project_type
		and pt.requires_billing = 1
		and pt.no_profit_till_end = 0
		$where_clause
	");

		# STEP 3: materials logs for projects with "at end" profit calculation
	_do_or_error($ds, "

		insert {~reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id,
					units, price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log.log_source, log.log_id, 1, log.amount_billed
		from {~timer}.materials_log log, {~timer}.project p,
				{~timer}.project_type pt
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

		insert {~reporting}.profit_item
			(client_id, proj_id, start_date, end_date, log_source, log_id, units,
					price_per_unit)
		select log.client_id, log.proj_id, log.log_date, log.log_date,
				log_source, log_id,
				datediff(minute, log.start_time, log.end_time) / 60.0
						- (isnull(log.num_breaks, 0) * .25),
				log.num_students * br.rate
		from {~timer}.class_log log, {~timer}.project p,
				{~timer}.project_type pt, {~timer}.bill_rate br
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
		insert {~reporting}.time_log_profit
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
			from {~reporting}.time_log_profit tlp
			where log.log_source = tlp.log_source
			and log.log_id = tlp.log_id
		)
=cut

		# whew! now that we have all the profit items set, we can calculate
		# the total price (which is after all the point of all this)
	_do_or_error($ds, "

		update {~reporting}.profit_item
		set total_price = units * price_per_unit
	");

	# we don't really want any output from this
	return "";
}


###########################################################################
#
# calc_profit
#
# #########################################################################
#
# This procedure calls calc_total_cost and all the commission procedures
# and uses that info to figure out the total profit.  Be sure and call
# build_profit_item (above) before calling this procedure.  After you call
# this, you probably don't need to call anything else.
#
# Since this procedure uses the existing profit_item table, and none of
# the procedures it calls require any arguments, it requires no arguments
# of its own.
#
###########################################################################

sub calc_profit
{
	my ($ds) = @_;
	my $output = "";						# usually this will remain empty

	$output .= calc_sales_commission($ds);
	$output .= calc_referral_commission($ds);
	$output .= calc_total_cost($ds);
	$output .= calc_employee_commission($ds);

	# fixup NULL commissions; NULL won't add properly
	_do_or_error($ds, '
		update {@profit_item}
		set sales_commission = 0
		where sales_commission is NULL
	');
	_do_or_error($ds, '
		update {@profit_item}
		set ref_commission = 0
		where ref_commission is NULL
	');
	_do_or_error($ds, '
		update {@profit_item}
		set emp_commission = 0
		where emp_commission is NULL
	');

	# simple profit calculation is basic subtraction
	_do_or_error($ds, '

		update {@profit_item}
		set simple_profit = total_price - total_cost - sales_commission
				- ref_commission - emp_commission
	');

	# fill up profit_client for some helpful reporting stuff
	my $data = $ds->load_table('

		select pi.client_id, pi.proj_id, min(pi.start_date) "start_date",
				max(pi.end_date) "end_date", sum(pi.units) "units",
				sum(pi.total_price) "total_price",
				sum(pi.total_cost) "total_cost",
				sum(pi.sales_commission) "sales_commission",
				sum(pi.ref_commission) "ref_commission",
				sum(pi.emp_commission) "emp_commission",
				sum(pi.simple_profit) "simple_profit"
		from {@profit_item} pi
		group by pi.client_id, pi.proj_id

	') or _fatal($ds);

		# margin calculation is pretty basic
		# (make sure you don't divide by zero or get negative margins
		# or magins over 100%)
	$data->alter_dataset({
			add_columns		=>	[ qw<margin> ],
			foreach_row		=>	sub
			{
				if ($_->{total_price} > 0 and $_->{simple_profit} > 0
						and $_->{total_price} > $_->{simple_profit})
				{
					$_->{margin} = range::round(
							$_->{simple_profit} / $_->{total_price} * 100,
							range::ROUND_OFF, .01);
				}
				else
				{
					$_->{margin} = undef;
				}
			}

	});

	# jam it in the table
	$ds->replace_table('{@profit_client}', $data)
			or _fatal($ds);

	# pass on any output received from subprocedures
	return $output;
}


###########################################################################
#
# calc_total_cost
#
# #########################################################################
#
# This procedure works out the cost for each profit item so that you can
# calculate the profit.  Most of the stuff here is pretty basic.  It sort of
# expects build_profit_item (and, by extension, build_pay_amount) to have
# been called already.
#
# Since this procedure uses the existing profit_item table, it requires
# no arguments of its own.
#
###########################################################################

sub calc_total_cost
{
	my ($ds) = @_;

	# materials_log has total cost already in it
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@profit_item}', 'pi',
		# set
			[ 'total_cost = ml.amount_paid' ],
		'
			from {@materials_log} ml
			where pi.log_source = ml.log_source
			and pi.log_id = ml.log_id
	');

	# update time_log_profit from pay_amount
	# note that this join doesn't check log_source, but this should
	# be okay since both time_log_profit and pay_amount should be
	# filled up from time_log (only) ... if this ever changes,
	# this update will no longer work properly
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@time_log_profit}', 'tlp',
		# set
			[ 'pay_rate_type = pa.pay_rate_type', 'total_pay = pa.total_pay' ],
		'
			from {@pay_amount} pa
			where tlp.log_id = pa.log_id
	');

	# can update "one to one" time logs directly
	_fatal($ds) unless defined $ds->correlated_update(

		# update
			'{@profit_item}', 'pi',
		# set
			[ ' total_cost = tlp.total_pay' ],
		'
			from {@time_log_profit} tlp
			where pi.log_source = tlp.log_source
			and pi.log_id = tlp.log_id
	');

	# build a dataset for updating everything else
	my $data = $ds->load_table(q<

		select pi.profit_id, sum(tlp.total_pay) "total_cost"
		from {@profit_item} pi, {@time_log_profit} tlp
		where pi.log_source in ('time_log FIXED', 'time_log SUM',
				'class_log', 'class_log SUM')
		and pi.client_id = tlp.client_id
		and pi.proj_id = tlp.proj_id
		and tlp.log_date between pi.start_date and pi.end_date
		group by pi.profit_id

	>);

	# and use dataset to update the profit item table
	foreach (@$data)
	{
		_do_or_error($ds, '

			update {@profit_item}
			set total_cost = {total_cost}
			where profit_id = {profit_id}
		',
			%$_
		);
	}

	# no output necessary
	return "";
}


###########################################################################
#
# calc_sales_commission
#
# #########################################################################
#
# Use this procedure to calculate the sales commission for a given set
# of profit items.  Be sure and call build_profit_item (above) before calling
# this procedure.
#
# Since this procedure uses the existing profit_item table, it requires no
# arguments of its own.
#
###########################################################################


sub calc_sales_commission
{
	my ($ds) = @_;

	my $data = $ds->load_table('

		-- first, the project specific sales commissions
		select pi.profit_id, sc.pay_type, sc.pay_to, pi.client_id, pi.proj_id,
				pi.total_price, sc.commission_percent
		from {@profit_item} pi, {@sales_commission} sc
		where pi.client_id = sc.client_id
		and pi.proj_id = sc.proj_id
		and pi.end_date between sc.start_date and sc.end_date

		-- now, the general client sales comms, but not if already superseded
		union
		select pi.profit_id, sc.pay_type, sc.pay_to, pi.client_id, pi.proj_id,
				pi.total_price, sc.commission_percent
		from {@profit_item} pi, {@sales_commission} sc
		where pi.client_id = sc.client_id
		and sc.proj_id is NULL
		and pi.end_date between sc.start_date and sc.end_date
		and not exists
		(
			select 1
			from {@profit_item} pi2, {@sales_commission} sc2
			where pi.profit_id = pi2.profit_id
			and pi2.client_id = sc2.client_id
			and pi2.proj_id = sc2.proj_id
			and pi2.end_date between sc2.start_date and sc2.end_date
		)

	') or _fatal($ds);

		# now figure the amounts of the commissions (not too tough)
		# also take advantage of this opportunity to transform the dataset
		# into the form we want (i.e., to match the sales_comm_amount table)
	$data->alter_dataset({
			add_columns		=>	[ qw<name amount> ],
			remove_columns	=>	[ qw<total_price> ],
			foreach_row		=>	sub
			{
				$_->{amount} = range::round(
						$_->{total_price} * $_->{commission_percent} / 100,
						range::ROUND_OFF, .01);
			}
	});

	# jam it in the table
	$ds->replace_table('{@sales_comm_amount}', $data)
			or _fatal($ds);

		# get the name of the commission payee if an employee
	_do_or_error($ds, q<

		update {@sales_comm_amount}
		set name = pe.first_name
		from {@sales_comm_amount} sca, {@employee} e, {@person} pe
		where sca.pay_type = 'E'
		and sca.pay_to = e.emp_id
		and e.person_id = pe.person_id
	>);

		# get the name of the commission payee if a salesman
	_do_or_error($ds, q<

		update {@sales_comm_amount}
		set name = s.name
		from {@sales_comm_amount} sca, {@salesman} s
		where sca.pay_type = 'S'
		and sca.pay_to = s.salesman_id
	>);

		# create a grouped dataset we can use to update the profit_item table
	$data = $data->group(

			group_by	=>	[ qw<profit_id> ],
			new_columns	=>	[ qw<profit_id total_sales_comm> ],
			on_new_group=>	sub
							{
								$_->{total_sales_comm} = 0;
							},
			calculate	=>	sub
							{
								my ($src, $dst) = @_;

								$dst->{total_sales_comm} += $src->{amount};
							},
	);
	return "couldn't group commissions by profit_id for some reason\n"
			unless $data;

	# finally update the profit item table
	foreach (@$data)
	{
		_do_or_error($ds, '

			update {@profit_item}
			set sales_commission = {total_sales_comm}
			where profit_id = {profit_id}
		',
			%$_
		);
	}

	# no output necessary
	return "";
}


###########################################################################
#
# calc_referral_commission
#
# #########################################################################
#
# Use this procedure to calculate the referral commission for a given set
# of profit items.  Be sure and call build_profit_item (above) before calling
# this procedure.
#
# Since this procedure uses the existing profit_item table, it requires no
# arguments of its own.
#
###########################################################################


sub calc_referral_commission
{
	my ($ds) = @_;

	my $data = $ds->load_table(q<

		-- first get the "one-to-one" time logs
		select pi.profit_id, rc.pay_type, rc.pay_to, tlp.emp_id, tlp.hours,
				rc.commission
		from {@profit_item} pi, {@time_log_profit} tlp,
				{@referral_commission} rc
		where pi.log_source = tlp.log_source
		and pi.log_id = tlp.log_id
		and tlp.emp_id = rc.emp_id
		and tlp.log_date between rc.start_date and rc.end_date

		-- next, everything else (except the materials logs)
		union
		select pi.profit_id, rc.pay_type, rc.pay_to, tlp.emp_id, tlp.hours,
				rc.commission
		from {@profit_item} pi, {@time_log_profit} tlp,
				{@referral_commission} rc
		where pi.log_source in ('time_log FIXED', 'time_log SUM',
				'class_log', 'class_log SUM')
		and pi.client_id = tlp.client_id
		and pi.proj_id = tlp.proj_id
		and tlp.log_date between pi.start_date and pi.end_date
		and tlp.emp_id = rc.emp_id
		and tlp.log_date between rc.start_date and rc.end_date

	>) or _fatal($ds);

		# now figure the amounts of the commissions (not too tough)
		# also take advantage of this opportunity to transform the dataset
		# into the form we want (i.e., to match the referral_comm_amount table)
	$data->alter_dataset({
			add_columns		=>	[ qw<name amount> ],
			foreach_row		=>	sub
			{
				$_->{amount} = range::round(
						$_->{hours} * $_->{commission}, range::ROUND_OFF, .01);
			}
	});

	# jam it in the table
	$ds->replace_table('{@referral_comm_amount}', $data)
			or _fatal($ds);

		# get the name of the commission payee if an employee
	_do_or_error($ds, q<

		update {@referral_comm_amount}
		set name = pe.first_name
		from {@referral_comm_amount} sca, {@employee} e, {@person} pe
		where sca.pay_type = 'E'
		and sca.pay_to = e.emp_id
		and e.person_id = pe.person_id
	>);

		# get the name of the commission payee if a salesman
	_do_or_error($ds, q<

		update {@referral_comm_amount}
		set name = s.name
		from {@referral_comm_amount} sca, {@salesman} s
		where sca.pay_type = 'S'
		and sca.pay_to = s.salesman_id
	>);

		# create a grouped dataset we can use to update the profit_item table
	$data = $data->group(

			group_by	=>	[ qw<profit_id> ],
			new_columns	=>	[ qw<profit_id total_ref_comm> ],
			on_new_group=>	sub
							{
								$_->{total_ref_comm} = 0;
							},
			calculate	=>	sub
							{
								my ($src, $dst) = @_;

								$dst->{total_ref_comm} += $src->{amount};
							},
	);
	return "couldn't group commissions by profit_id for some reason\n"
			unless $data;

	# finally update the profit item table
	foreach (@$data)
	{
		_do_or_error($ds, '

			update {@profit_item}
			set ref_commission = {total_ref_comm}
			where profit_id = {profit_id}
		',
			%$_
		);
	}

	# no output necessary
	return "";
}


###########################################################################
#
# calc_employee_commission
#
# #########################################################################
#
# Use this procedure to calculate the employee commission for a given set
# of profit items.  Be sure and call build_profit_item (above) before calling
# this procedure.
#
# Since this procedure uses the existing profit_item table, it requires no
# arguments of its own.
#
###########################################################################


sub calc_employee_commission
{
	my ($ds) = @_;

	my $data = $ds->load_table(q<

		-- get the "one on one" time logs
		select pi.profit_id, tlp.emp_id "pay_to", tlp.log_date "comm_date",
				tlp.total_pay "pay_to_employee", pi.total_cost "total_pay",
				pi.total_price, pi.sales_commission, pi.ref_commission
		from {@profit_item} pi, {@time_log_profit} tlp
		where pi.log_source = tlp.log_source
		and pi.log_id = tlp.log_id
		and tlp.requires_payment = 1
		and tlp.pay_rate_type != 'S'

		-- now the other time logs
		union
		select pi.profit_id, tlp.emp_id "pay_to", tlp.log_date "comm_date",
				sum(tlp.total_pay) "pay_to_employee", pi.total_cost "total_pay",
				pi.total_price, pi.sales_commission, pi.ref_commission
		from {@profit_item} pi, {@time_log_profit} tlp
		where pi.log_source in ('time_log FIXED', 'time_log SUM',
				'class_log', 'class_log SUM')
		and pi.client_id = tlp.client_id
		and pi.proj_id = tlp.proj_id
		and tlp.log_date between pi.start_date and pi.end_date
		and tlp.requires_payment = 1
		and tlp.pay_rate_type != 'S'
		group by pi.profit_id, tlp.emp_id, tlp.log_date, pi.total_cost

	>) or _fatal($ds);

		# now figure the amounts of the commissions (pretty complicated)
		# also take advantage of this opportunity to transform the dataset
		# into the form we want (i.e., to match the employee_comm_amount table)
	$data->alter_dataset({
			add_columns		=>	[ qw<pay_type name amount> ],
			remove_columns	=>	[ qw<total_price
									sales_commission ref_commission> ],
			foreach_row		=>	sub
			{
				# employee commission is always paid to employees
				$_->{pay_type} = 'E';

				# now figure the percent of total pay that applies to
				# this employee (note that for the "one to one" logs,
				# this will always be 100%)
				my $employee_percent = $_->{pay_to_employee} / $_->{total_pay};

				# these might be NULL (i.e., undef), so zero them if necessary
				$_->{sales_commission} ||= 0;
				$_->{ref_commission} ||= 0;

				# now figure the adjusted price (i.e., total price -
				# (sales comm + ref comm)) and the difference between
				# adjusted cost and total cost; for historical reasons,
				# these are called the gross and diff
				my $gross = $employee_percent * ($_->{total_price}
						- $_->{sales_commission} - $_->{ref_commission});
				my $diff = $gross - $_->{pay_to_employee};

				# turn the dates we need into Perl numbers
				my $comm_change_date = timelocal(0,0,0,7,9,98);		# 9/7/98
				my $comm_date = str2time($_->{comm_date});

				# now the commission itself:
				# no diff, no comm
				if ($diff <= 0)
				{
					$_->{amount} = 0;
				}
				# old formula (previous to magic date of 9/7/98) is easy
				elsif ($comm_date < $comm_change_date)
				{
					$_->{amount} = $diff * .04;
				}
				# new formula is somewhat bitchy
				else
				{
					my $rate_factor = 12.0;
					my $breakeven_factor = 3.0;
					my $flare_factor = 20.0;
					$_->{amount} = $diff * $diff / (
								($gross / $rate_factor) -
										($diff - $gross / $breakeven_factor)
												/ $flare_factor
							) / 100.0
				}

				# round it off
				$_->{amount} = range::round($_->{amount},
						range::ROUND_OFF, .01);
			}
	});

	# jam it in the table
	$ds->replace_table('{@employee_comm_amount}', $data)
			or _fatal($ds);

		# get the name of the commission payee (it's always an employee)
	_do_or_error($ds, q<

		update {@employee_comm_amount}
		set name = pe.first_name
		from {@employee_comm_amount} sca, {@employee} e, {@person} pe
		where sca.pay_type = 'E'
		and sca.pay_to = e.emp_id
		and e.person_id = pe.person_id
	>);

		# create a grouped dataset we can use to update the profit_item table
	$data = $data->group(

			group_by	=>	[ qw<profit_id> ],
			new_columns	=>	[ qw<profit_id total_emp_comm> ],
			on_new_group=>	sub
							{
								$_->{total_emp_comm} = 0;
							},
			calculate	=>	sub
							{
								my ($src, $dst) = @_;

								$dst->{total_emp_comm} += $src->{amount};
							},
	);
	return "couldn't group commissions by profit_id for some reason\n"
			unless $data;

	# finally update the profit item table
	foreach (@$data)
	{
		_do_or_error($ds, '

			update {@profit_item}
			set emp_commission = {total_emp_comm}
			where profit_id = {profit_id}
		',
			%$_
		);
	}

	# no output necessary
	return "";
}


###########################################################################
#
# calc_admin_commission
#
# #########################################################################
#
# Use this procedure to calculate the administrative commission for a given
# set of profit items.  You have to call calc_profit before calling this.
#
# Like all the commission calculation procedures, this procedure uses the
# existing profit_item table and requires no arguments of its own.
#
###########################################################################


sub calc_admin_commission
{
	my ($ds) = @_;

	# for admin_commission, *everything* in the profit_item table is
	# applicable, so we don't track the profit_id ...  this is also
	# important to insure that admin commissions (which are often
	# pretty small) don't lose anything from overenthusiastic
	# rounding ... if you need to know which profit_id's apply (e.g.,
	# for the mark_commission script), the answer is easy: all of them
	my $data = $ds->load_table(q<

		select ac.admin_comm, ac.pay_type, ac.pay_to,
				ac.start_date "comm_start_date", ac.end_date "comm_end_date",
				ac.commission_percent, sum(pi.simple_profit) "simple_profit"
		from {@profit_item} pi, {@admin_commission} ac
		where pi.end_date between ac.start_date and ac.end_date
		group by ac.admin_comm, ac.pay_type, ac.pay_to, ac.start_date,
				ac.end_date, ac.commission_percent

	>) or _fatal($ds);

	# calculate commission amount
	$data->alter_dataset({
			add_columns		=>	[ qw<amount> ],
			foreach_row		=>	sub
			{
				$_->{amount} = range::round(
						$_->{simple_profit} * $_->{commission_percent} / 100,
						range::ROUND_OFF, .01);
			}
	});

	# jam it in the table
	$ds->replace_table('{@admin_comm_amount}', $data)
			or _fatal($ds);

		# get the name of the commission payee if an employee
	_do_or_error($ds, q<

		update {@admin_comm_amount}
		set name = pe.first_name
		from {@admin_comm_amount} sca, {@employee} e, {@person} pe
		where sca.pay_type = 'E'
		and sca.pay_to = e.emp_id
		and e.person_id = pe.person_id
	>);

		# get the name of the commission payee if an employee
	_do_or_error($ds, q<

		update {@admin_comm_amount}
		set name = pe.first_name
		from {@admin_comm_amount} sca, {@employee} e, {@person} pe
		where sca.pay_type = 'E'
		and sca.pay_to = e.emp_id
		and e.person_id = pe.person_id
	>);

		# get the name of the commission payee if a salesman
	_do_or_error($ds, q<

		update {@admin_comm_amount}
		set name = s.name
		from {@admin_comm_amount} sca, {@salesman} s
		where sca.pay_type = 'S'
		and sca.pay_to = s.salesman_id
	>);

	# no output necessary
	return "";
}


###########################################################################
#
# calc_salary_bank
#
# #########################################################################
#
# Use this procedure to calculate how an employee's actual pay affects his
# or her salary bank, for all employees on the salary bank program.
#
# The following aliases are available to your where clause:
#
#		sd			salary draw table
#
# Your where clause needs to be based on sd.start_date or sd.end_date
# (preferably both, as with a between expression) to insure that you don't
# get any duplicates.
#
###########################################################################


sub calc_salary_bank
{
	my ($ds, $where_clause) = @_;

		# get the salary data
	my $data = $ds->load_table('

		select sd.emp_id, sd.amount_per_period, sd.max_debit,
				sd.max_overage, sd.periods_cap
		from {@salary_draw} sd
		where ' . $where_clause

	) or _fatal($ds);

		# we'll also need total pay data
	my $pay_data = $ds->load_table('

		select pa.emp_id, sum(pa.total_pay) as total_pay
		from {@pay_amount} pa
		group by pa.emp_id

	') or _fatal($ds);

		# turn our total pay data into a hash
	my $total_pay = {};
	$pay_data->foreach_row(sub
	{
		$total_pay->{$_->{emp_id}} = $_->{total_pay};
	});

		# we also need to know how much is in the salary bank at the moment
	my $bank_data = $ds->load_table('

		select sb.emp_id, sb.bank_amount
		from {@salary_bank} sb, {@payroll} pay
		where sb.payroll_id = pay.payroll_id
		and pay.period_end =
		(
			select max(pay2.period_end)
			from {@salary_bank} sb2, {@payroll} pay2
			where sb.emp_id = sb2.emp_id
			and sb2.payroll_id = pay2.payroll_id
			and pay2.period_end < {start_date}
		)

	') or _fatal($ds);
	$bank_data->dump_set() if DEBUG >= 5;

		# turn our bank before amount data into a hash
	my $bank_before = {};
	foreach (@$bank_data)
	{
		$bank_before->{$_->{emp_id}} = $_->{bank_amount};
	}

		# calculate the actual amounts
	$data->alter_dataset({
			add_columns		=>	[ qw<actual_pay total_pay bank_before>,
									qw<bank_after bank_adjustment> ],
			remove_columns	=>	[ qw<amount_per_period max_debit max_overage>,
									qw<periods_cap> ],
			foreach_row		=>	sub
			{
				my $salary_amt = $_->{amount_per_period};
				my $max_debit_amount = $salary_amt * $_->{max_debit};
				my $max_overage_amount = $salary_amt * $_->{max_overage};
				my $overcap_threshhold = $salary_amt * $_->{periods_cap};
				my $undercap_threshhold = $overcap_threshhold * -1;

				my $emp_id = $_->{emp_id};
				if (exists $total_pay->{$emp_id})
				{
					$_->{total_pay} = $total_pay->{$emp_id};
				}
				else
				{
					$_->{total_pay} = 0;
				}
				if (exists $bank_before->{$emp_id})
				{
					$_->{bank_before} = $bank_before->{$emp_id};
				}
				else
				{
					$_->{bank_before} = 0;
				}

				my $total_pay = $_->{total_pay};
				my $bank_before = $_->{bank_before};
				if ($total_pay >= $salary_amt)
				{
					my $overage = range::max(
							$total_pay - $max_overage_amount, 0);
					my $overcap = range::max($total_pay - $salary_amt
							- $overage + $bank_before
							- $overcap_threshhold, 0);
					$_->{actual_pay} = $salary_amt + $overage + $overcap;
				}
				else					# $total_pay < $salary_amt
				{
					my $overage = $salary_amt - $total_pay;
					# max debit should not kick in till bank is totally
					# exhausted, thus the addition of the two below
					$overage = range::min($overage,
									$max_debit_amount + $bank_before)
							if $bank_before > 0 and $bank_before - $overage < 0;
					$overage = $bank_before - $undercap_threshhold
							if $bank_before - $overage < $undercap_threshhold;
					$_->{actual_pay} = $total_pay + $overage;
				}

				$_->{bank_adjustment} = $total_pay - $_->{actual_pay};
				$_->{bank_after} = $bank_before + $_->{bank_adjustment};
			}
	});

	# finally, put it in the table
	$ds->replace_table('{@salary_amount}', $data)
			or _fatal($ds);

	# no output necessary
	return "";
}


###########################################################################
#
# calc_insurance_contribution
#
# #########################################################################
#
# Use this procedure when you want to calculate the amounts that the company
# will contribute to health insurance payments.
#
# No where clause is necessary for this procedure.  It expects the records
# it needs to have been placed into the {~reporting}.pay_amount table
# (probably by build_pay_amount or build_profit_item).
#
###########################################################################


sub calc_insurance_contribution
{
	my ($ds) = @_;

		 # first get insurance records for fixed amounts
	my $fixed_data = $ds->load_data('

		select pa.emp_id, tl.payroll_id,
				ir.fixed_amount as company_contribution,
				sum(pa.hours) as total_hours
		from {@pay_amount} pa, {@insurance_rate} ir, {@time_log} tl
		where ir.emp_id = pa.emp_id
		and pa.pay_date between ir.start_date and ir.end_date
		and pa.log_source = tl.log_source
		and pa.log_id = tl.log_id
		and ir.fixed_amount is not NULL
		group by pa.emp_id, tl.payroll_id, ir.fixed_amount

	') or _fatal($ds);
	print STDERR "got ", scalar(@$fixed_data),
			" rows for insurance fixed amt\n" if DEBUG >= 2;

	# use group function to insure there is only one contribution
	# we'll also set applicable hours to NULL
	$fixed_data = $fixed_data->group(

			group_by	=>	[ qw<emp_id payroll_id> ],
			new_columns	=>	[ qw<emp_id payroll_id total_hours>,
								qw<applicable_hours company_contribution> ],
			constant	=>	[ qw<company_contribution total_hours> ],
			on_new_group=>	sub
							{
								$_->{applicable_hours} = undef;
							},
	);
	return "calc_insurance_contribution: can't have more than one fixed "
			. "amount contribution per employee/payroll\n" unless $fixed_data;


		 # now get insurance records for calculated amounts
	my $calc_data = $ds->load_data('

		select pa.emp_id, tl.payroll_id, ir.nonbill_hrs_limit,
				ir.multiplier, pa.pay_date, pa.hours,
				pa.requires_billing, pa.requires_payment
		from {@pay_amount} pa, {@insurance_rate} ir, {@time_log} tl
		where ir.emp_id = pa.emp_id
		and pa.pay_date between ir.start_date and ir.end_date
		and pa.log_source = tl.log_source
		and pa.log_id = tl.log_id

	') or _fatal($ds);
	print STDERR "got ", scalar(@$calc_data), " rows for insurance calcs\n"
			if DEBUG >= 2;

	# calculation step 1: get week numbers for each date
	$calc_data->add_column(week_num => sub
	{
		date::period_num($_->{pay_date}, 7);
	});
	DataStore::dump_set($calc_data) if DEBUG >= 5;

	# calculation step 2: group data by weeks, totalling hours
	$calc_data = $calc_data->group(

			group_by	=>	[ qw<emp_id payroll_id week_num> ],
			new_columns	=>	[ qw<emp_id payroll_id week_num multiplier>,
								qw<nonbill_hrs_limit applicable_hours>,
								qw<bill_hours nonbill_hours total_hours> ],
			constant	=>	[ qw<nonbill_hrs_limit multiplier> ],
			on_new_group=>	sub
							{
								$_->{bill_hours} = 0;
								$_->{nonbill_hours} = 0;
								$_->{total_hours} = 0;
							},
			calculate	=>	sub
							{
								my ($src, $dst) = @_;
								print STDERR "columns in source row: ",
										join(',', keys %$src), "\n"
										if DEBUG >= 5;
								print STDERR "adding $src->{hours}\n"
										if DEBUG >= 4;

								$dst->{total_hours} += $src->{hours};
								if ($src->{requires_payment})
								{
									my $add_to = $src->{requires_billing}
											? 'bill_hours' : 'nonbill_hours';
									$dst->{$add_to} += $src->{hours};
								}
							},
	);
	return "calc_insurance_contribution: can't have more than one multiplier "
			. "or limit per employee/payroll/week\n" unless $calc_data;

	# calculation step 3: calculate applicable hours per week
	foreach (@$calc_data)
	{
		$_->{applicable_hours} = $_->{bill_hours}
				+ range::min($_->{nonbill_hours}, $_->{nonbill_hrs_limit});
	}

	# calculation step 4: group again, combining weeks
	$calc_data = $calc_data->group(
			group_by	=>	[ qw<emp_id payroll_id> ],
			new_columns	=>	[ qw<emp_id payroll_id total_hours>,
								qw<applicable_hours company_contribution>,
								qw<multiplier nonbill_hrs_limit> ],
			constant	=>	[ qw<nonbill_hrs_limit multiplier> ],
			on_new_group=>	sub
							{
								$_->{applicable_hours} = 0;
								$_->{total_hours} = 0;
							},
			calculate	=>	sub
							{
								my ($src, $dst) = @_;
								$dst->{total_hours} += $src->{total_hours};
								$dst->{applicable_hours}
										+= $src->{applicable_hours};
							},
	);
	# it really shouldn't be possible for this one to fail
	return "calc_insurance_contribution: unknown error on second grouping\n"
			unless $calc_data;

	# calculation step 5: calculate contribution
	$calc_data->alter_dataset({
			remove_columns	=>	[ qw<multiplier nonbill_hrs_limit> ],
			foreach_row		=>	sub
			{
				my $units = range::round($_->{applicable_hours} / 10,
						range::ROUND_DOWN);
				$_->{company_contribution} = $units * $_->{multiplier};
			}
	});


	# put both data sets in the table
	$ds->replace_table('{@insurance_amount}', $fixed_data,
			DataStore::EMPTY_SET_OKAY) or _fatal($ds);
	$ds->append_table('{@insurance_amount}', $calc_data,
			DataStore::EMPTY_SET_OKAY) or _fatal($ds);

	# no output necessary
	return "";
}



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
###########################################################################
# auxillary procedures
# for use with sundry DataSet's
###########################################################################
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


=comment
sub fred
{
	my ($data, $sql, $match_cols, $match_val,
			$date, $start_date, $end_date) = @_;

	# build up list of top-level id's
	# and sub it into the SQL
	my %top_ids;
	foreach ($@data)
	{
		$top_ids{$_->{$cols->[0]} = 1;
	}
	my $list = [ keys %top_ids ];
	$_ = "'$_'" foreach @$list;
	$list = join(',', @$list);
	$sql =~ s/in\s+\(\)/in ($list)/i;

	my $match_data = $ds->load_data($sql) or _fatal($ds);
	my $matches = [];
	foreach (@$match_data)
	{
		foreach my $num_matches ($#$match_cols)
		{
			my $curcol = $match_cols->[$num_matches];
			if (not defined $_->{$curcol})
			{
				$matches->[$num_matches] = {}
						unless defined $matches->[$num_matches];
				my $hash = $matches->[$num_matches];
				foreach my $mcol (@$match_cols[0..($num_matches-1)])
				{
					$hash = $hash->{$mcol};
				}
				push @{$hash->{$curcol}} = [ $_->{$match_val},
						$_->{$start_date}, $_->{$end_date} ];
				last;
			}
		}
	}

	$data->alter_dataset({
			add_columns		=>	[ $match_val ],
			foreach_row		=>	sub
			{
				MATCH_COL: foreach my $m (0..$#$match_cols)
				{
					my $possible_match = $matches->[$m];
					foreach my $mcol (0..$m)
					{
						next MATCH_COL unless exists $possible_match->{$mcol};
						$possible_match = $possible_match->{$mcol};
					}
					foreach $pm (@$possible_match)
					{
						if ($_->{$date} >= 
					}
				}
			}
	});
}
=cut
