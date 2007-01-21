###########################################################################
#
# Barefoot::DataStore::DataSet;
#
###########################################################################
#
# Some functions to help manipulate datasets, such as those returned by DataStore::load_table.
#
# #########################################################################
#
# All the code herein is released under the Artistic License
#		( http://www.perl.com/language/misc/Artistic.html )
# Copyright (c) 2002-2007 Barefoot Software, Copyright (c) 2007 ThinkGeek
#
###########################################################################

package DataStore::DataSet::Builder;

### Private ###############################################################

use strict;
use warnings;

use Barefoot;


###########################
# Subroutines:
###########################


sub new
{
	my ($class, $field_list, $index_hash) = @_;
	debuggit(2 => "Builder: column list ", join(',', @$field_list));

	# can build index_hash if we weren't given it
	unless ($index_hash)
	{
		$index_hash->{$field_list->[$_]} = $_ foreach 0..$#$field_list;
	}

	my $this = {};
	$this->{field_list} = $field_list;
	$this->{index_hash} = $index_hash;

	my $dataset = [];
	bless $dataset, 'DataStore::DataSet';
	$this->{dataset} = $dataset;

	bless $this, $class;
	return $this;
}


sub add_row
{
	my $this = $_[0];
	# can pass data as an arrayref, or omit for a blank row
	my $data = $_[1] || [ (undef) x scalar(@{$this->{field_list}}) ];

	my $new_row = DataStore::DataRow->new($this->{field_list}, $this->{index_hash}, $data);
	push @{$this->{dataset}}, $new_row;
	return $new_row;
}


sub dataset
{
	return $_[0]->{dataset};
}


###########################################################################


package DataStore::DataSet;

### Private ###############################################################

use strict;
use warnings;

use Carp;
use Data::Dumper;

use Barefoot;
use Barefoot::DataStore::DataRow;


###########################
# Subroutines:
###########################


sub new
{
	my ($class, $sth) = @_;

	# need copies of these, since some of our methods might modify them
	# if we don't make copies, we'd modify the statement parameters (and that would be bad)
	my @fields = @{ $sth->{NAME} };
	my %index = %{ $sth->{NAME_hash} };
	my $builder = DataStore::DataSet::Builder->new(\@fields, \%index);

	my $data = [];
	while (my $row = $sth->fetchrow_arrayref())
	{
		debuggit(4 => "row in DataSet: ", join(':', @$row));
		# *must* make a copy of $row because fetchrow_arrayref() returns
		# the same reference every time (see DBI manpage)
		$builder->add_row( [@$row] );
	}

	# check for error
	return undef if $sth->err();

	dump_set($data, *STDERR) if DEBUG >= 3;

	return $builder->dataset();
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


sub colnames
{
	# just pass through to our first DataRow
	# (note: this will bomb if called on an emtpy DataSet)
	return $_[0]->[0]->colnames();
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


sub alter_dataset
{
	my ($data, $opts) = @_;
	my $add_cols = $opts->{add_columns} || [];
	my $del_cols = $opts->{remove_columns} || [];

	# got to go into the DataRow's and twiddle the field list by hand
	# *)	we have to do this in two places: the array of fields, and the hash which links a field name to
	#		its index in the value array
	# *)	we only have to do this for one DataRow; since all rows in the set are linked to the same field
	#		list and index hash, updating one updates them all
	my $first_row = $data->[0];
	my $field_list = $$first_row->{impl}->[DataStore::DataRow::KEYS];
	my $index_hash = $$first_row->{impl}->[DataStore::DataRow::INDEX];

	# having $del_cols be the column names doesn't really do us a lot of good
	# what we really need is the column indices; so we get them here
	$_ = $index_hash->{$_} foreach @$del_cols;
	# it's really quite important to have the del indices in the right order
	# otherwise, splicing out the columns throws the indices off for the remaining splices
	$del_cols = [ reverse sort @$del_cols ];

	# handle columns to add first
	if (@$add_cols)
	{
		# remember size before we start adding to it
		my $index = @$field_list;
		# tack new column names onto end
		push @$field_list, @$add_cols;
		# update index entries for new names
		$index_hash->{$_} = $index++ foreach @$add_cols;
	}

	foreach (@$data)
	{
		# run the processor
		# this should presumably fill in any added columns
		# also, since we haven't taken out the remove_columns yet, the processor can refer to those columns too
		$opts->{foreach_row}->() if $opts->{foreach_row};

		# while we're here, and now that the processor is done, get rid of the data for the remove_columns
		# note this doesn't get rid of the column _names_, just the data
		# column names are removed after the loop
		my $row = $_;					# so we can use $_ for indices
		splice @$row, $_, 1 foreach @$del_cols;
	}

	# now handle any removed columns
	if (@$del_cols)
	{
		# take the column names out of the field list
		splice @$field_list, $_, 1 foreach @$del_cols;

		# finally, rebuild index hash
		# this insures that the hash will be correct
		%$index_hash = ();
		$index_hash->{$field_list->[$_]} = $_ foreach 0..$#$field_list;
	}

	return $data;
}


sub group
{
	my ($data, %opts) = @_;

	return undef if not exists $opts{group_by};
	return undef if not exists $opts{new_columns};
	debuggit(2 => "group: new columns ", join(',', @{$opts{new_columns}}));

	my @group_by_cols = @{$opts{group_by}};
	my (@constant_cols, $process);
	@constant_cols = @{$opts{constant}} if exists $opts{constant};
	$process = $opts{calculate} if exists $opts{calculate};

	my $group_data = DataStore::DataSet::Builder->new($opts{new_columns});
	my $group_data_hash = {};
	foreach my $src (@$data)
	{
		my @group_by_vals;
		push @group_by_vals, defined $src->{$_} ? $src->{$_} : "\x00" foreach @group_by_cols;
		my $group_by_vals = join($;, @group_by_vals);
		debuggit(4 => "group by vals are", $group_by_vals);

		my $dst;
		if (exists $group_data_hash->{$group_by_vals})
		{
			$dst = $group_data_hash->{$group_by_vals};

			# have to check to make sure constant cols are the same
			foreach my $col (@constant_cols)
			{
				my $src_col = $src->{$col};
				my $dest_col = $dst->{$col};

				if (not defined $src_col)
				{
					# if source col is NULL, dest col must be NULL too
					debuggit(3 => "source col not defined, dest col", $dest_col) if defined $dest_col;
					return undef if defined $dest_col;
				}
				else
				{
					# source col not NULL, so dest col must be not NULL
					# and equal (doing string equal here)
					debuggit(3 => "source col", $src_col, "dest col not defined") if not defined $dest_col;
					debuggit(3 => "source col", $src_col, "dest col", $dest_col)
							if defined $dest_col and $src_col ne $dest_col;
					return undef unless defined $dest_col and $src_col eq $dest_col;
				}
			}
		}
		else
		{
			# put a blank row in the dataset, then save it in the hash
			$dst = $group_data_hash->{$group_by_vals} = $group_data->add_row();
			die("not a DataRow in new group create") unless $dst->isa('DataStore::DataRow');
			print Data::Dumper->Dump( [$$dst->{impl}], qw<dst> ) if DEBUG >= 4;

			$dst->{$_} = $src->{$_} foreach @group_by_cols;
			$dst->{$_} = $src->{$_} foreach @constant_cols;
			if (exists $opts{on_new_group})
			{
				local $_ = $dst;
				$opts{on_new_group}->();
			}
		}

		$process->($src, $dst) if defined $process;
	}
	debuggit(4 => Data::Dumper->Dump( [$group_data], [ qw<group_data> ] ));

	# now sort group_data into a new dataset (new_data)
	my $new_data = [];
	foreach (sort keys %$group_data_hash)
	{
		die("not a DataRow ($_) in sorting") unless $group_data_hash->{$_}->isa('DataStore::DataRow');
		push @$new_data, $group_data_hash->{$_};
	}

	# make sure new_data is a DataSet, like us
	return bless $new_data, ref $data;
}


sub add_column
{
	my ($data, $colname, $adder_sub) = @_;
	croak("must specify column to add") unless $colname;
	croak("must specify a subroutine to calculate new values") unless $adder_sub;

	# this is the same deal as in alter_dataset(); see comments there
	my $first_row = $data->[0];
	my $field_list = $$first_row->{impl}->[DataStore::DataRow::KEYS];
	# tack new column name onto end
	push @$field_list, $colname;
	# now update index hash
	$$first_row->{impl}->[DataStore::DataRow::INDEX]->{$colname} = $#$field_list;

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
	# and make some shortcuts
	my $field_list = $$first_row->{impl}->[DataStore::DataRow::KEYS];
	my $index_hash = $$first_row->{impl}->[DataStore::DataRow::INDEX];

	# get array index for column from index hash
	my $idx = $index_hash->{$colname};
	# remove column from field list
	splice @$field_list, $idx, 1;

	# now rebuild index hash
	%$index_hash = ();
	$index_hash->{$field_list->[$_]} = $_ foreach 0..$#$field_list;

	# now remove the data from each row
	foreach my $row (@$data)
	{
		splice @$row, $idx, 1;
	}

	return $data;
}


sub rename_column
{
	my ($data, $old_col, $new_col) = @_;

	my $first_row = $data->[0];
	my $idx = delete $$first_row->{impl}->[DataStore::DataRow::INDEX]->{$old_col};
	croak("unknown column name: $old_col") unless $idx;

	$$first_row->{impl}->[DataStore::DataRow::KEYS]->[$idx] = $new_col;
	$$first_row->{impl}->[DataStore::DataRow::INDEX]->{$new_col} = $idx;
	return true;
}


###########################
# Return a true value:
###########################

1;
