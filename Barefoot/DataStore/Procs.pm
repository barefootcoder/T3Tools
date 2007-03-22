###########################################################################
#
# Barefoot::DataStore::Procs
#
###########################################################################
#
# This module contains a few "stored procedures" that will build dynamic SQL that will hopefully make your
# life easier (that is, hopefully they will make your code shorter without also making it less legible).
#
# All these procs are optional, so, if you don't like them, do them the long way.  However, remember that
# sometimes these help build queries which are complex and/or repetitive in standard SQL, so don't fall into
# the trap of replacing their use with non-standard (i.e., RDBMS-specific) SQL.  Each procedure contains a
# description of what it takes and what it corresponds to in various RDBMSes, as well as what it corresponds
# to in standard SQL.
#
# PLEASE NOTE: When we say "standard SQL", we don't necessarily mean "SQL as defined by the ANSI standard" (in
# any of its incarnations), although hopefully it _will_ be a subset of the latest ANSI standard.  The truth
# is that many very popular RDBMSes don't truly support the standard yet.  What we mean by "standard SQL" is,
# then, the following: "SQL which will be accepted by a majority of the RDBMSes on the market, *hopefully*
# including, at a minimum, Sybase, Oracle, Informix, and Postgres."  Historically, we've omitted MySQL from
# that list, but MySQL 4 could probably fit in there.  Mostly.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2007 Barefoot Software, Copyright (c) 2006-2007 ThinkGeek
#
###########################################################################

package DataStore;

### Private ###############################################################

use strict;
use warnings;

use Carp;

use Barefoot::DataStore;


# have to "register" all procs with DataStore
$DataStore::procs->{correlated_update} = \&correlated_update;
$DataStore::procs->{update_or_insert} = \&update_or_insert;



#
# Subroutines:
#


###########################################################################
#
# correlated_update
#
# #########################################################################
#
# Use this procedure to handle updating the contents of one table with values from another table.  You would
# call this proc like so:
#
#		my $num_rows = $ds->correlated_update("dest_tbl", "dt",
#				[ "col1 = st.col1", "col2 = st.col2" ],
#				"		from source_tbl st
#						where dt.id = st.id
#				");
#
# or, if you want to structure it so it looks a bit more like SQL:
#
#		my $num_rows = $ds->correlated_update(
#				# update
#					dest_tbl => "dt",
#				# set
#					[ "col1 = st.col1", "col2 = st.col2" ],
#				q{
#					from source_tbl st
#					where dt.id = st.id
#				}
#		);
#
# This builds (and executes) the standard SQL query:
#
#		update dest_tbl
#		set col1 =
#			(
#				select st.col1
#				from source_tbl st
#				where dest_tbl.id = st.id
#			),
#		col2 =
#			(
#				select st.col2
#				from source_tbl st
#				where dest_tbl.id = st.id
#			)
#		where exists
#		(
#				select 1
#				from source_tbl st
#				where dest_tbl.id = st.id
#		)
#
# This might be done in Sybase as:
#
#		update dest_tbl
#		set col1 = st.col1, col2 = st.col2
#		from dest_tbl dt, source_tbl st
#		where dt.id = st.id
#
# or it might be done in Oracle as:
#
#		update dest_tbl dt
#		set (col1, col2) =
#			(
#				select st.col1, st.col2
#				from source_tbl st
#				where dt.id = st.id
#			)
#		where exists
#		(
#			select 1
#			from source_tbl st
#			where dt.id = st.id
#		)
#
# but neither of these is standard SQL.
#
# Please note the following caveats:
#
#		1)	If you're used to Sybase, you may be tempted to add the table you're updating into the from
#			clause.  Don't do that.
#
#		2)	Don't put any aliases before the _destination_ column names.  You'll almost certainly need aliases
#			before the source column names, however.
#
#		3)	The alias you supply (as the second argument) better not be reused in the from/where clause you
#			supply.
#
#		4)	If you're using MySQL 4.0, 3,x (or, <insert deity of choice> forbid, lower), this isn't going to
#			work no matter what you do, because MySQL doesn't support subqueries.  You'll have to rewrite your
#			update as a select into a temp table, a delete, and an insert.  MySQL 4.1 and up should handle it
#			okay.
#
#		5)	If you don't correlate your destination table into your from/where clause, you're going to get
#			into trouble.
#
#		6)	Even if you do correlate your destination table, it better be the case that there's a one-to-one
#			correspondence between source table and destination table (zero-to-one is okay too).  Otherwise
#			the subquery(s) will return more than one row and the SQL will fail.  (Note that the same is _not_
#			true of the Sybase-specific equivalent, which would just blithely update each row in the
#			destination table multiple times.  This is better, IMHO.)
#
#		7)	Whitespace is irrelevant in your from/where clause _and_ in your column assigments.  However, this
#			is *not* true in your table name and alias name.
#
#		8)	Theoretically, your from/where clause can be arbitrarily complex.  You might even have more than
#			one source table.  That should be okay.  No guarantees though; you may want to think about just
#			what it's going to turn into before you start getting really wacky.
#
#		9)	This is all done via very simple substitutions, mainly for reasons of speed.  This means that you
#			_could_ get into trouble in some pathological cases.  For instance, if your destination alias was
#			"Mr" and part of your where clause was "and st.fullname = 'Mr.Jones'", this is going to bomb,
#			because the proc isn't smart enough to realize that "Mr.Jones" is in quotes, and it will treat it
#			just like a column named "Jones" in your destination table.  That's got to be frighteningly rare,
#			though: note that if your alias was "mr" instead, or you had a space after the "Mr.", you wouldn't
#			trigger it.  Just be careful.
#
# The return value is either the number of rows updated, or undef if the query failed (in which case you
# should check $ds->last_error()).
#
###########################################################################

sub correlated_update
{
	my $this = shift;
	my ($tablename, $alias, $assignments, $from_where_clause) = @_;

	# standard SQL doesn't allow a correlation name (alias) for the
	# update table, so replace the alias in the from/where clause
	# with the full table name
	$from_where_clause =~ s/
								\b			# starting at a word boundary
								$alias		# the alias itself
								(?=			# followed by (but don't sub!)
									\.		# a literal dot
									\w		# and some alpha character
								)
							# replace with literal tablename
							/$tablename/xg;

	# now loop through the assignments and turn them into subqueries
	foreach (@$assignments)
	{
		my ($source_col, $dest_col) = / ^ \s* (.*?) \s* = \s* (.*?) \s* $ /x;
		my $subquery = "( select $dest_col $from_where_clause )";
		$_ = "$source_col = $subquery";
	}

	# finally, the query:
	my $query = "update $tablename set " . join(",", @$assignments)
			. " where exists ( select 1 $from_where_clause )";

	my $res = $this->do($query);
	return $res ? $res->rows_affected : undef;
}


###########################################################################
#
# update_or_insert
#
# #########################################################################
#
# This one is much simpler, comparatively.  Basically, it tries to update a row, and if that doesn't work, it
# inserts it instead.  So you do this:
#
#		my $res = $ds->update_or_insert( dest_tbl => q{ where key = 1 },
#		{
#			key => 1,
#			col1 => 'a',
#			col2 => 'b',
#		});
#		if ($res and $res->rows_affected() == 1)
#		{
#			print "row successfully added/changed\n";
#		}
#		else
#		{
#			print "DB error! ", $ds->last_error(), "\n";
#		}
#
# which is basically just like doing this:
#
#		my $res = $ds->do(q{
#			update dest_tbl
#			set ???
#			where key = 1
#		},{
#			col1 => 'a',
#			col2 => 'b',
#		});
#		if ($res and $res->rows_affected == 0)
#		{
#			$res = $ds->do(q{ insert into dest_tbl values ??? },
#			{
#				key => 1,
#				col1 => 'a',
#				col2 => 'b',
#			});
#		}
#		if ($res and $res->rows_affected() == 1)
#		{
#			print "row successfully added/changed\n";
#		}
#		else
#		{
#			print "DB error! ", $ds->last_error(), "\n";
#		}
#
# except it's a hell of a lot shorter and quite a bit less repetitive.  Note the following things:
#
#	1)	Whatever you use as a where clause is of course only used by the update, but you'd best make sure that
#		your hash contains the values that your where clause is searching for.  Otherwise, your update can't
#		possibly match the values that your insert is inserting, and your update and insert can't possibly be
#		operating on the same row, which sort of defeats the whole purpose.
#
#	2) To facilitate this, your values are also sent as variables to do() for the update query.  Thus, the
#		following works as expected:
#
#			my $res = $ds->update_or_insert( dest_tbl => q{ where key = {key} },
#			{
#				key => 1,
#				col1 => 'a',
#				col2 => 'b',
#			});
#
#	3)	Of course, including the search values in the hash means that when you're updating, you're updating
#		those columns as well, which isn't really necessary.  But you're replacing them with the exact same
#		values, so it doesn't really hurt anything.
#
#	4)	Your where clause's search values should be unique.  If your where clause can return multiple rows,
#		then you're updating multiple rows, and once again you're out of sync with your insert (which is
#		definitely only going to insert one row).
#
# If you have timestamps or userstamps that need to be added for every update and/or insert call, you can do
# something like this at the top of your program:
#
#		update_or_insert_set_stamps(insert => { created_by => $ENV{USER}, created_on => '{&now}' },
#									update => { modified_by => $ENV{USER}, modified_on => '{&now}' });
#
# Of course, if you do this you can only use update_or_insert with tables that contain those fields.  You may
# also feel free to use the same hash for both insert and update, or specify only one or the other instead of
# both.  Using update_or_insert_set_stamps() is currently the only way to get different values for your update
# than for your insert.
#
###########################################################################

BEGIN
{
	my (%insert_stamps, %update_stamps);

	sub update_or_insert_set_stamps
	{
		my $this = shift;
		my %stamp_sets = @_;

		while (my ($trigger, $stamps) = each %stamp_sets)
		{
			if ($trigger eq 'insert')
			{
				%insert_stamps = %$stamps;
			}
			elsif ($trigger eq 'update')
			{
				%update_stamps = %$stamps;
			}
			else
			{
				croak("update_or_insert_set_stamps: unknown trigger $trigger");
			}
		}
	}

	sub update_or_insert
	{
		my $this = shift;
		my ($table, $where, $values) = @_;

		my $res = $this->do("update $table set ??? $where", { %$values, %update_stamps }, %$values);
		if ($res and $res->rows_affected() == 0)
		{
			$res = $this->do("insert into $table values ???", { %$values, %insert_stamps });
		}
		return $res;
	}
}


###########################
# Return a true value:
###########################

1;
