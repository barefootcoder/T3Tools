#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# Barefoot::DataStore::DataSet;
#
###########################################################################
#
# Some functions to help manipulate datasets, such as those returned
# by DataStore::load_table.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

package DataStore::DataSet;

### Private ###############################################################

use strict;

use Carp;

use Barefoot::base;
use Barefoot::DataStore::DataRow;


###########################
# Subroutines:
###########################


sub new
{
	my ($class, $sth) = @_;

	# need copies of these, since some of our methods might modify them
	# if we don't make copies, we'd modify the statement parameters
	# (and that would be bad)
	my @fields = @{ $sth->{NAME} };
	my %index = %{ $sth->{NAME_hash} };

	my $data = [];
	while (my $row = $sth->fetchrow_arrayref())
	{
		print STDERR "row in DataSet: ", join(':', @$row), "\n" if DEBUG >= 3;
		# *must* make a copy of $row because fetchrow_arrayref() returns
		# the same reference every time (see DBI manpage)
		push @$data, DataStore::DataRow->new(\@fields, \%index, [ @$row ]);
	}

	# check for error
	return undef if $sth->err();

	dump_set($data, *STDERR) if DEBUG >= 3;

	bless $data, $class;
}


# for debugging purposes
sub dump_set
{
	my ($data, $fh) = @_;
	my $oldfh;
	$oldfh = select($fh) if ($fh);

	foreach my $x (0..$#$data)
	{
		print "row ", $x + 1, ": ";
		print "$_ => $data->[$x]->{$_}; " foreach sort keys %{$data->[$x]};
		print "\n";
	}

	select $oldfh if $fh;
}


sub foreach_row
{
	my ($data, $func) = @_;

	foreach (@$data)
	{
		&$func;
	}

	return $data;
}


sub group
{
	my ($data, %opts) = @_;

	return undef if not exists $opts{group_by};
	my @group_by_cols = @{$opts{group_by}};
	my (@constant_cols, $process);
	@constant_cols = @{$opts{constant}} if exists $opts{constant};
	$process = $opts{calculate} if exists $opts{calculate};

	my $group_data = {};
	foreach my $src (@$data)
	{
		my @group_by_vals;
		push @group_by_vals, defined $src->{$_} ? $src->{$_} : "\x00"
				foreach @group_by_cols;
		my $group_by_vals = join($;, @group_by_vals);
		print STDERR "group by vals are $group_by_vals\n" if DEBUG >= 4;

		my $dst;
		if (exists $group_data->{$group_by_vals})
		{
			$dst = $group_data->{$group_by_vals};

			# have to check to make sure constant cols are the same
			foreach my $col (@constant_cols)
			{
				my $src_col = $src->{$col};
				my $dest_col = $dst->{$col};

				if (not defined $src_col)
				{
					# if source col is NULL, dest col must be NULL too
					print STDERR "source col not defined, dest col $dest_col\n"
							if defined $dest_col and DEBUG >= 3;
					return undef if defined $dest_col;
				}
				else
				{
					# source col not NULL, so dest col must be not NULL
					# and equal (doing string equal here)
					print STDERR "source col $src_col, dest col not defined\n"
							if not defined $dest_col and DEBUG >= 3;
					print STDERR "source col $src_col, dest col $dest_col\n"
							if defined $dest_col and $src_col ne $dest_col
								and DEBUG >= 3;
					return undef unless defined $dest_col
							and $src_col eq $dest_col;
				}
			}
		}
		else
		{
			$group_data->{$group_by_vals} = {};
			$dst = $group_data->{$group_by_vals};

			$dst->{$_} = $src->{$_} foreach @group_by_cols;
			$dst->{$_} = $src->{$_} foreach @constant_cols;
		}

		$process->($src, $dst) if defined $process;
	}

	my $new_data = [];
	foreach (sort keys %$group_data)
	{
		push @$new_data, $group_data->{$_};
	}

	return $new_data;
}


sub add_column
{
	my ($data, $colname, $adder_sub) = @_;
	croak("must specify column to remove") unless $colname;
	croak("must specify a subroutine to calculate new values")
			unless $adder_sub;

	# got to go into the DataRow's and twiddle the field list by hand
	# Note 1) we have to do this in two places: the array of fields, and
	#	the hash which links a field name to its index in the value array
	# Note 2) we only have to do this for one DataRow; since all rows in
	#	the set are linked to the same field list and index hash, updating
	#	one updates them all
	my $first_row = $data->[0];
	my $field_list = $$first_row->{impl}->[DataStore::DataRow::KEYS];
	# tack new column name onto end
	push @$field_list, $colname;
	# now update index hash
	$$first_row->{impl}->[DataStore::DataRow::INDEX]->{$colname}
			= $#$field_list;

	# now we can use the sub to calculate the new values
	# row should be $_ so sub can refer to that if it wants
	foreach (@$data)
	{
		$_->{$colname} = &$adder_sub;
	}

	return $data;
}


sub remove_column
{
	my ($data, $colname) = @_;
	croak("must specify column to remove") unless $colname;

	# got to go into the DataRow's and twiddle the field list by hand
	# all comments under add_column (above) apply
	my $first_row = $data->[0];
	# remove column from index hash, saving array index
	my $idx = delete
			$$first_row->{impl}->[DataStore::DataRow::INDEX]->{$colname};
	# remove column from field list
	my $field_list = $$first_row->{impl}->[DataStore::DataRow::KEYS];
	splice @$field_list, $idx, 1;

	# now remove the data from each row
	foreach my $row (@$data)
	{
		splice @$row, $idx, 1;
	}

	return $data;
}


###########################
# Return a true value:
###########################

1;
