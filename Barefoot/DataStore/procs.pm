#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::DataStore::procs
#
###########################################################################
#
# This module contains a few "stored procedures" that will build dynamic
# SQL that will hopefully make your life easier (that is, hopefully they
# will make your code shorter without also making it less legible).
#
# All these procs are optional, so, if you don't like them, do them the
# long way.  However, remember that sometimes these help build queries
# which are complex and/or repetitive in standard SQL, so don't fall into
# the trap of replacing their use with non-standard (i.e., RDBMS-specific)
# SQL.  Each procedure contains a description of what it takes and what
# it corresponds to in various RDBMSes, as well as what it corresponds to
# in standard SQL.
#
# PLEASE NOTE: When we say "standard SQL", we don't necessarily mean "SQL
# as defined by the ANSI standard" (in any of its incarnations), although
# hopefully it _will_ be a subset of the latest ANSI standard.  The truth
# is that many very popular RDBMSes don't truly support the standard yet.
# What we mean by "standard SQL" is, then, the following: "SQL which will
# be accepted by a majority of the RDBMSes on the market, *hopefully*
# including, at a minimum, Sybase, Oracle, Informix, and Postgres."  Note
# that we don't include MySQL.  There's just too much stuff missing from
# MySQL to make it worth trying to keep up with.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package DataStore;

### Private ###############################################################

use strict;

use Barefoot::DataStore;


# have to "register" all procs with DataStore
$DataStore::procs->{correlated_update} = \&correlated_update;


1;


#
# Subroutines:
#


###########################################################################
#
# correlated_update
#
# #########################################################################
#
# Use this procedure to handle updating the contents of one table with values
# from another table.  You would call this proc like so:
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
#					"dest_tbl", "dt",
#				# set
#					[ "col1 = st.col1", "col2 = st.col2" ],
#				"
#					from source_tbl st
#					where dt.id = st.id
#				"
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
#		1) If you're used to Sybase, you may be tempted to add the
#			table you're updating into the from clause.  Don't do that.
#		2) Don't put any aliases before the _destination_ column names.
#			You'll almost certainly need aliases before the source column
#			names, however.
#		3) The alias you supply (as the second argument) better not be
#			reused in the from/where clause you supply.
#		4) If you're using MySQL, this isn't going to work no matter what
#			you do, because MySQL doesn't support subqueries.  You'll have
#			to rewrite your update as a select into a temp table, a delete,
#			and an insert.
#		5) If you don't correlate your destination table into your from/where
#			clause, you're going to get into trouble.
#		6) Even if you do correlate your destination table, it better be
#			the case that there's a one-to-one correspondence between source
#			table and destination table (zero-to-one is okay too).  Otherwise
#			the subquery(s) will return more than one row and the SQL will
#			fail.  (Note that the same is _not_ true of the Sybase-specific
#			equivalent, which would just blithely update each row in the
#			destination table multiple times.  This is better, IMHO.)
#		7) Whitespace is irrelevant in your from/where clause _and_ in your
#			column assigments.  However, this is *not* true in your table
#			name and alias name.
#		8) Theoretically, your from/where clause can be arbitrarily complex.
#			You might even have more than one source table.  That should
#			be okay.  No guarantees though; you may want to think about
#			just what it's going to turn into before you start getting
#			really wacky.
#		9) This is all done via very simple substitutions, mainly for
#			reasons of speed.  This means that you _could_ get into
#			trouble in some pathological cases.  For instance, if your
#			destination alias was "Mr" and part of your where clause was
#			"and st.fullname = 'Mr.Jones'", this is going to bomb, because
#			the proc isn't smart enough to realize that "Mr.Jones" is in
#			quotes, and it will treat it just like a column named "Jones"
#			in your destination table.  That's got to be frighteningly
#			rare, though: note that if your alias was "mr" instead, or
#			you had a space after the "Mr.", you wouldn't trigger it.
#			Just be careful.
#
# The return value is either the number of rows updated, or undef if the
# query failed (in which case you should check $ds->last_error()).
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
