#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::DataStore::display
#
###########################################################################
#
# The display() function accepts a file which contains mostly basic SQL
# commands, with the possible addition of some more sophisticated formatting
# options, and produces a string which is (hopefully) ready for printing.
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

# don't try to turn on debugging here; do it in DataStore.pm instead

use Barefoot::range;
use Barefoot::string;
use Barefoot::DataStore;
use Barefoot::T3::TimerProcs;
use Barefoot::DataStore::procs;

1;


#
# Subroutines:
#


# the main event
# (helper routines are below)
sub display
{
	my ($ds, $filename) = @_;

	croak("cannot display with no data store")
			unless $ds and $ds->isa("DataStore");

	my ($display, $query, $command, $command_arg) = ("", "", "", "");

	CORE::open(IN, $filename) or croak("cannot open file $filename");
	while ( <IN> )
	{
		s/ \# .* $ //x;						# remove comments
		next if /^\s*$/;					# skip blank lines

		if ( / ^ \s* ; \s* $ /x )			# end of query or command arg
		{
			if ($command)					# must be end of command arg
			{
				$display .= $command->($ds, $command_arg);
				$command = "";				# reset command
			}
			else							# must be end of query
			{
				# get output unless entire query is blank
				$display .= _process($ds, $query)
						unless $query =~ /^\s*$/;
				$display .= "\n" unless substr($display, -2) eq "\n\n";
				$query = "";				# reset the query
			}
			next;
		}

		# only check for special commands if $query is blank
		print STDERR "line is $_ and query is $query\n" if DEBUG >= 4;
		if ( / ^ \s* & (\w+) (?: \s+ (.*?) )? $ /x and not $query )
		{
			$command = $1;
			print STDERR "processing command $command\n" if DEBUG >= 2;

			# each command is potentially different, so figure out which one
			if ($command eq 'proc')
			{
				print STDERR "proc is $2\n" if DEBUG >= 2;

				# $2 should be our proc name, so let's double check that
				croak("unknown procedure call: $2")
						unless exists $DataStore::procs->{$2};

				# okay, now we'll need the SQL clause for this procedure,
				# so we'll let the loop build up $command_arg and then
				# call it
				$command = $DataStore::procs->{$2};
			}
			elsif ($command eq 'ignore')
			{
				# we want to ignore everything up until the next ;
				# so we'll just let it collect in $command_arg,
				# and provide a "do nothing" subroutine to call
				$command = sub { "" };
			}
			else
			{
				croak("unknown command: $command");
			}

			# if we get this far, that means somebody wants to build up
			# $command_arg.  so we'll reset it and then loop around again
			$command_arg = "";
			next;
		}

		# if we've survived this far, we need to tack the current line onto
		# something.  if there's a current command, tack it onto the command
		# argument.  otherwise, tack it onto the query
		if ($command)
		{
			$command_arg .= $_;
		}
		else
		{
			$query .= $_;
		}
	}
	close(IN);

	return $display;
}


#####
# Helper Routines
#####

# got a query, now handle it
sub _process
{
	my ($ds, $query) = @_;

	my $res = $ds->do($query);
	return $ds->last_error() unless $res;

	if (not $res->{sth}->{NUM_OF_FIELDS})	# it's not a select query
	{
		my $rows = $res->rows_affected();
		return $rows == -1 ? "" : "($rows rows affected)\n";
	}

	# loop through columns and get names
	my @colnames = ();
	my @widths = ();
	my $numcols = $res->num_cols();
	for (my $x = 0; $x < $numcols; ++$x)
	{
		my $name = $res->colname($x);
		push @colnames, $name;
		push @widths, [ length($name) ];
	}

	# loop through rows and get data
	my $rowcount = 0;
	my @rows = ();
	while ($res->next_row())
	{
		my @cols = $res->all_cols();
		for (my $x = 0; $x < $numcols; ++$x)
		{
			push @{$widths[$x]}, length($cols[$x]) if $cols[$x];
		}
		push @rows, [ @cols ];
	}
	continue
	{
		++$rowcount;
	}

	# get header rows
	my $output = "";
	$output .= _build_header(\@colnames, \@widths);

	# get data rows
	$output .= _build_rows(\@rows, \@widths);

	$output .= "($rowcount rows returned)\n";
	return $output;
}


sub _build_header
{
	my ($colnames, $colsizes) = @_;

	my ($nameline, $separator_line) = ("", "");
	for (my $x = 0; $x < @$colnames; ++$x)
	{
		my $width = range::max(@{$colsizes->[$x]});
		$colsizes->[$x] = $width;

		$nameline .= " " if $x;
		$separator_line .= " " if $x;
		$nameline .= string::pad($colnames->[$x], $width);
		$separator_line .= "-" x $width;
	}

	return "$nameline\n$separator_line\n";
}

sub _build_rows
{
	my ($colvalues, $colsizes) = @_;

	my $rows = "";
	foreach my $row (@$colvalues)
	{
		for (my $x = 0; $x < @$colsizes; ++$x)
		{
			$rows .= " " if $x;
			$rows .= string::pad($row->[$x], $colsizes->[$x]);
		}
		$rows .= "\n";
	}

	return $rows;
}
