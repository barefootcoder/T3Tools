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

package DataStore;

### Private ###############################################################

use strict;


1;


#
# Subroutines:
#


# for debugging purposes
sub dump_set
{
	my ($data) = @_;

	foreach my $x (0..$#$data)
	{
		print "row ", $x + 1, ": ";
		print "$_ => $data->[$x]->{$_}; " foreach sort keys %{$data->[$x]};
		print "\n";
	}
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


sub remove_column
{
	my ($data, $colname) = @_;
	croak("must specify column to remove") unless $colname;

	foreach my $row (@$data)
	{
		delete $row->{$colname};
	}

	return $data;
}
