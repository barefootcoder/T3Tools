#! /usr/local/bin/perl -w

# For RCS:
# $Date$
#
# $Id$
# $Revision$

###########################################################################
#
# DataStore::DataRow
#
###########################################################################
#
# This object allows both name and number access to values, similar to
# a Perl pseudo-hash (only smarter).
#
# NOTE: DataStore::DataRow is tested as part of DataStore.  Check out
# ../test_DataStore for test-first stuff.
#
# #########################################################################
#
# All the code herein is Class II code according to your software
# licensing agreement.  Copyright (c) 2002 Barefoot Software.
#
###########################################################################

### Private ###############################################################

use strict;

package DataStore::DataRow::impl;

use Carp;

use constant INDEX	=> 0;
use constant KEYS	=> 1;
use constant VALUES	=> 2;
use constant ITER	=> 3;

sub TIEHASH
{
	my ($class, $key_array, $index_hash, $val_array) = @_;

	bless [ $index_hash, $key_array, $val_array, 0 ], $class;
}

sub FETCH
{
=unoptomized_code
	my ($self, $key) = @_;

	croak("unknown column name $key") unless exists $self->[INDEX]->{$key};
	return $self->[VALUES]->[ $self->[INDEX]->{$key} ];
=cut
	return exists $_[0]->[INDEX]->{$_[1]}
			? $_[0]->[VALUES]->[ $_[0]->[INDEX]->{$_[1]} ]
			: croak("unknown column name $_[1]");
}

sub STORE
{
=unoptomized_code
	my ($self, $key, $value) = @_;

	croak("trying to create unknown key $key")
			unless exists $self->[INDEX]->{$key};
	$self->[VALUES]->[ $self->[INDEX]->{$key} ] = $value;
=cut
	exists $_[0]->[INDEX]->{$_[1]}
			? ($_[0]->[VALUES]->[ $_[0]->[INDEX]->{$_[1]} ] = $_[2])
			: croak("trying to create unknown key $_[1]");
}

sub DELETE
{
	croak("not allowed to delete keys");
}

sub EXISTS
{
=unoptomized_code
	my ($self, $key) = @_;

	return exists $self->[INDEX]->{$key};
=cut
	return exists $_[0]->[INDEX]->{$_[1]};
}

sub FIRSTKEY
{
=unoptomized_code
	my ($self) = @_;

	$self->[ITER] = 0;
	NEXTKEY($self);
=cut
	$_[0]->[ITER] = 0;
	NEXTKEY($_[0]);
}

sub NEXTKEY
{
=unoptomized_code
	my ($self) = @_;

	if ($self->[ITER] >= @{ $self->[KEYS] })
	{
		return undef;
	}
	else
	{
		return $self->[KEYS]->[ $self->[ITER]++ ];
	}
=cut
	return $_[0]->[KEYS]->[ $_[0]->[ITER]++ ]
		if $_[0]->[ITER] < @{ $_[0]->[KEYS] };
	return undef;
}


1;



package DataStore::DataRow;

use Carp;

use Barefoot::base;

# just repeated from impl above
use constant INDEX	=> 0;
use constant KEYS	=> 1;
use constant VALUES	=> 2;
use constant ITER	=> 3;

use overload
(
	'%{}'	=> sub { ${$_[0]}->{hash} },
	'@{}'	=> sub { ${$_[0]}->{impl}->[VALUES] },

	# ostensibly, a DataRow should always be true
	# don't construct DataRow's if you don't have any data
	bool	=> sub { 1 },
);


###########################
# Subroutines:
###########################


sub new
{
	my ($class, $fields, $index_hash, $data, $calc_funcs, $vars) = @_;

	my $this = \{};
	my %tied_hash;
	$$this->{impl} = tie %tied_hash, 'DataStore::DataRow::impl',
			$fields, $index_hash, $data;
	$$this->{hash} = \%tied_hash;
	$$this->{vars} = $vars;

	bless $this, $class;

	# figure out vals for calculated columns (if any)
	# (must have already blessed $this before doing this!)
	if ($calc_funcs and %$calc_funcs)
	{
		for (my $i = 0; $i < @$fields; ++$i)
		{
			if (substr($fields->[$i], 0, 1) eq '*')
			{
				my $true_colname = substr($fields->[$i], 1);
				croak("calc column with no calc function: $true_colname")
						unless exists $calc_funcs->{$true_colname};
				print STDERR "function for $true_colname will return ",
						$calc_funcs->{$true_colname}->($this), "\n"
							if DEBUG >= 4;
				$data->[$i] = $calc_funcs->{$true_colname}->($this);
			}
		}
	}

	return $this;
}


sub num_cols
{
	my $this = shift;

	return scalar @{ $$this->{impl}->[VALUES] };
}


sub col
{
	my ($this, $col_id) = @_;

	return $col_id =~ /^\d/ ? $this->[$col_id] : $this->{$col_id};
}


###########################
# Helper Subroutines:
###########################


sub _var
{
=unoptomized_code
	my ($this, $varname) = @_;

	return $$this->{vars}->{$varname};
=cut
	return ${$_[0]}->{vars}->{$_[1]};
}


sub _get_colnum
{
	my ($this, $name) = @_;

	print STDERR "checking for column name: $name\n" if DEBUG >= 3;
	croak("unknown column name $name")
			unless exists $$this->{impl}->[INDEX]->{$name};
	print STDERR "found column name: $name\n" if DEBUG >= 5;
	return $$this->{impl}->[INDEX]->{$name};
}


###########################
# Return a true value:
###########################

1;
